"""  Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
  
  Licensed under the Apache License, Version 2.0 (the "License").
  You may not use this file except in compliance with the License.
  You may obtain a copy of the License at
  
      http://www.apache.org/licenses/LICENSE-2.0
  
  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
"""
import json
import os
import uuid
from datetime import datetime, timezone

import valkey as redis
from botocore.exceptions import NoCredentialsError
from flask import (
    Flask,
    abort,
    flash,
    make_response,
    redirect,
    render_template,
    request,
    send_file,
    session,
    url_for,
)
from flask_session import Session
from flask_wtf.csrf import CSRFProtect
from forms.forms import DragDropScan, SetupProwlerScan
from modules.batches import get_batch_jobs, get_log_stream
from modules.filemod import file_mod
from modules.fileupload import FileUpload
from modules.quotaset import gatekeeper
from modules.scanparams import fn_submit_job, set_env
from modules.simplyred import RedisClient
from modules.snssubs import get_my_topic, process_topic
from modules.tools import Tools
from modules.utilities import aws_session, getRegions, isauth, populate_tools
from modules.validators import form_validator, prowler_validate
from modules.verifyjwt import decode_jwt

app = Flask(__name__, static_folder="static")
app.config.from_object("config.Config")
csrf = CSRFProtect()
csrf.init_app(app)

basedir = os.path.abspath(os.path.dirname(__file__))

try:
    app.config["SESSION_REDIS"] = redis.from_url("redis://localhost:6379")
    server_redis = RedisClient("localhost", 6379, 1)
except Exception:
    app.config["SESSION_REDIS"] = redis.from_url("redis://redis:6379")
    server_redis = RedisClient("redis", 6379, 1)


server_session = Session(app)


def getcaller():
    if not server_redis.exists("MY_REGION"):
        isauth(session, server_redis, app.config)
    my_region = server_redis.get("MY_REGION")
    fn_session = aws_session(my_region)
    sts_url = "https://sts." + my_region + ".amazonaws.com"
    sts = fn_session.client("sts", endpoint_url=sts_url)
    try:
        return sts.get_caller_identity()
    except NoCredentialsError as err:
        return err


def parsecreds(cred) -> dict:
    new_set = cred.splitlines()
    new_list = {x.replace("export ", "") for x in new_set}
    return dict(map(str, x.split("=", 1)) for x in new_list)


def read_checks(input_file) -> dict:
    if not server_redis.exists("PROWLER_CHECKS"):
        check_dict = {}
        with open(input_file, "r", encoding="utf-8") as checkfile:
            sp = checkfile.read()

            lines = sp.split("\n")
            for line in sorted(lines):
                if line:
                    pair_extract = line.replace("_", " ")
                    check_dict[line] = pair_extract.upper()
        server_redis.set("PROWLER_CHECKS", check_dict)

    return server_redis.get("PROWLER_CHECKS")


def updateScans(bs):
    dt = datetime.now(timezone.utc)
    current_time = dt.strftime("%Y-%m-%d %H:%M:%S")
    batch_id = {"jobId": bs["jobId"], "jobName": bs["jobName"], "time": current_time}
    if session["BATCH_SCANS"]:
        scan_ids = json.loads(session["BATCH_SCANS"])
        scan_ids.append(batch_id)
        session["BATCH_SCANS"] = json.dumps(scan_ids)
    else:
        scan_ids = []
        scan_ids.append(batch_id)
        session["BATCH_SCANS"] = json.dumps(scan_ids)


def batch_scan(
    sf_region_list,
    sf_account,
    sf_checks_joined,
    sf_sub_name,
    sf_exclude,
    t,
    sf_external_id,
    sf_role_name,
    sf_bucket_role_arn,
    sf_custom_bucket,
    sf_both_buckets,
    sf_bucket_external_id,
):
    my_job_name = "prowler-" + sf_sub_name
    scan_arn = "arn:aws:iam::" + sf_account + ":role/" + sf_role_name
    environment_list = set_env(
        session,
        server_redis,
        t,
        external_id=sf_bucket_external_id,
        external_bucket=sf_custom_bucket.lower(),
        role_arn=sf_bucket_role_arn,
        both_buckets=sf_both_buckets,
    )
    command_list = [
        "-f",
        sf_region_list,
        "-R",
        scan_arn,
        "-I",
        sf_external_id,
        "-z",
    ]
    if len(sf_checks_joined) > 1:
        split_checks = sf_checks_joined.split()
        if len(split_checks) > 20:
            flash("Please limit your checks to 20 or less.", "danger")
            return redirect(url_for("index"))
        elif not all([i in server_redis.get("PROWLER_CHECKS") for i in split_checks]):
            flash("The compliance check selected was invalid.", "danger")
            return redirect(url_for("index"))
        else:
            command_list.extend([sf_exclude, sf_checks_joined])
    my_region = server_redis.get("MY_REGION")
    fn_session = aws_session(my_region)
    container_overrides = {"command": command_list, "environment": environment_list}
    response = fn_submit_job(fn_session, my_job_name, t.job_queue, t.job_definition, container_overrides)
    return response


def get_tool_info(tool_name):
    cache_lookup = server_redis.get("TOOL_DETAIL")
    match = next(
        (label for label in cache_lookup if label["TOOL_NAME"]["S"] == tool_name),
        None,
    )
    return match


@app.after_request
def add_header(response):
    csp_data = "default-src 'none'; font-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self' data:; object-src 'none'; frame-ancestors 'none'; base-uri 'none'; upgrade-insecure-requests"
    response.headers["Content-Security-Policy"] = csp_data
    return response


@app.route("/", methods=["GET"])
def index():
    authtest = isauth(session, server_redis, app.config)
    populate_tools(server_redis, app.config["MY_TOOL_TABLE"])
    return render_template(
        "home.html",
        homeic="secondary",
        ia=authtest,
        tools=server_redis.get("TOOL_DETAIL"),
    )


@app.route("/<my_tool>/", methods=["GET", "POST"])
def my_scan_tool(my_tool):
    message = gatekeeper(session)
    if message:
        flash(message, "danger")
        return redirect(url_for("index"))
    populate_tools(server_redis, app.config["MY_TOOL_TABLE"])
    t = Tools(
        my_tool,
        server_redis.get("TOOLS_ALLOWED"),
        server_redis.get("MY_TOOL_TABLE"),
        server_redis,
    )
    if my_tool not in t.scan_tools() and my_tool != "multiscan":
        abort(404)

    authtest = isauth(session, server_redis, app.config)

    session["LAST_URL"] = url_for("my_scan_tool", my_tool=my_tool)
    if authtest:
        decode_jwt(session, server_redis)
        if not session["SUB_STAT"] == "Subscribed":
            return redirect(url_for("snssetup"))
        scan_form = DragDropScan()

    if scan_form.validate_on_submit():
        message = gatekeeper(session, decrement=True)
        if message:
            flash(message, "danger")
            return redirect(url_for("index"))
        custom_bucket = scan_form.custom_bucket.data
        custom_bucket = custom_bucket.lower()
        evaluate = form_validator(
            scan_form.external_id.data,
            custom_bucket,
            scan_form.role_arn.data,
            scan_form.both_buckets.data,
        )
        if not isinstance(evaluate, bool):
            session["TMP_FLASH"] = [
                evaluate,
                "danger",
            ]
            return render_template(
                "scan.html",
                gridic="secondary",
                my_tool=my_tool,
                meta=t.tool_meta,
                scan_form=scan_form,
                ia=authtest,
            )
        else:
            external_id = scan_form.external_id.data
            role_arn = scan_form.role_arn.data
            if scan_form.both_buckets.data:
                both_buckets = "0"
            else:
                both_buckets = "1"
        f = request.files
        file_list = 0
        sf_sub_name = session["sub"].replace("-", "")
        for file in f:
            uploaded_file = f.get(file)
            dst = session["SESSION_ID"] + "/" + uploaded_file.filename
            FileUpload(uploaded_file, t.job_input_bucket, dst).file_upload_s3()
            file_list += 1
        my_job_name = my_tool + "-" + sf_sub_name

        if str.isdigit(scan_form.ai_radio.data):
            ai_radio = int(scan_form.ai_radio.data)
        else:
            ai_radio = 0
        if my_tool == "bedrock" and ai_radio == 0:
            ai_radio = 1
        elif ai_radio in range(0, 4):
            ai_radio = ai_radio
        else:
            ai_radio = 0
        # Creating a list of tools
        my_region = server_redis.get("MY_REGION")
        fn_session = aws_session(my_region)
        my_tool_list = [my_tool]
        depends_on_list = []
        if my_tool == "multiscan":
            my_tool_dict = Tools.tools_of_type("multiscan", server_redis)
            my_tool_list = list(my_tool_dict.keys())
        # Start Loop here
        for tool in my_tool_list:
            t = Tools(
                tool,
                server_redis.get("TOOLS_ALLOWED"),
                server_redis.get("MY_TOOL_TABLE"),
                server_redis,
            )
            environment_list = set_env(
                session,
                server_redis,
                t,
                external_id=external_id,
                external_bucket=custom_bucket.lower(),
                role_arn=role_arn,
                both_buckets=both_buckets,
                ai_prompt=str(ai_radio),
            )
            container_overrides = {"environment": environment_list}
            bs = fn_submit_job(
                fn_session,
                my_job_name,
                t.job_queue,
                t.job_definition,
                container_overrides,
            )
            bs["jobName"] = tool
            updateScans(bs)
            depends_on_list.append({"jobId": bs["jobId"], "type": "SEQUENTIAL"})
        if my_tool != "bedrock" and ai_radio in range(1, 4):
            ai = fn_submit_job(
                fn_session,
                f"bedrock-{sf_sub_name}",
                "NoInternetQueue",
                "BedRockDefinition",
                container_overrides,
            )
            ai["jobName"] = "bedrock"
            updateScans(ai)
            depends_on_list.append({"jobId": ai["jobId"], "type": "SEQUENTIAL"})
        fn_submit_job(
            fn_session,
            f"lastcontainer-{sf_sub_name}",
            "NoInternetQueue",
            "LastContainerDefinition",
            container_overrides,
            depends_on=depends_on_list,
        )
        session.pop("SESSION_ID")
        session["SESSION_ID"] = uuid.uuid4().hex
        session["TMP_BS"] = bs
        session["TMP_IA"] = authtest
        session["TMP_FILE_LIST"] = file_list
        flash(f"Files upload: {file_list}", "success")
        return render_template(
            "scan.html",
            gridic="secondary",
            my_tool=my_tool,
            meta=t.tool_meta,
            scan_form=scan_form,
            ia=authtest,
            bs=bs,
        )
    else:
        return render_template(
            "scan.html",
            gridic="secondary",
            my_tool=my_tool,
            meta=t.tool_meta,
            scan_form=scan_form,
            ia=authtest,
        )


@app.route("/form-submit/", methods=["GET"])
def form_submit():
    if "TMP_IA" in session.keys():
        ia = session["TMP_IA"]
        bs = session["TMP_BS"]
        file_list = session["TMP_FILE_LIST"]
        for key in list(session.keys()):
            if key[:4] == "TMP_":
                session.pop(key)
        flash(f"Files upload: {file_list}", "success")
        meta = {"PRINT_NAME": "", "SHORT": "", "DESCRIPTION": ""}
        return render_template("scan.html", gridic="secondary", meta=meta, ia=ia, bs=bs)
    else:
        message = gatekeeper(session)
        if message:
            flash(message, "danger")
            return redirect(url_for("index"))
        else:
            return redirect(url_for("index"))


@app.route("/profile/", methods=["GET", "POST"])
def profile():
    input_dict = {}
    if request.method == "POST":
        formprofile = request.form["text_area"]
        input_dict = parsecreds(formprofile)
        for key in input_dict:
            session[key] = input_dict[key]
        gc = getcaller()
        authtest = isauth(session, server_redis, app.config)
        return render_template("profile.html", peopleic="secondary", getcall=gc, ia=authtest)
    else:
        gc = getcaller()
        authtest = isauth(session, server_redis, app.config)
        server_var_list = []
        get_server_vars = server_redis.keys()
        for item in get_server_vars:
            server_var_list.append(
                {
                    item: str(server_redis.get(item)),
                }
            )
        return render_template(
            "profile.html",
            peopleic="secondary",
            getcall=gc,
            ia=authtest,
            session_vars=session,
            server_vars=server_var_list,
        )


@app.route("/snssetup/", methods=["GET", "POST"])
def snssetup():
    sf_sub_name = session["sub"].replace("-", "")
    my_region = server_redis.get("MY_REGION")
    try:
        topic_check = get_my_topic(sf_sub_name, my_region)
        if topic_check:
            my_status = topic_check[1]
            session["SUB_STAT"] = my_status
        else:
            my_status = topic_check
            session["SUB_STAT"] = my_status
        if my_status == "Subscribed":
            session["SUB_STAT"] = my_status
            return redirect(session["LAST_URL"])
        else:
            process_topic(topic_check, sf_sub_name, session["email"], my_region)
            return render_template(
                "snssetup.html",
                speedic="secondary",
                my_status=my_status,
                email=session["email"],
            )
    except KeyError:
        return redirect(url_for("index"))


@app.route("/prowler/", methods=["GET", "POST"])
def prowler():
    authtest = isauth(session, server_redis, app.config)
    message = gatekeeper(session)
    if message:
        flash(message, "danger")
        return redirect(url_for("index"))
    if authtest:
        decode_jwt(session, server_redis)
        session["LAST_URL"] = url_for("prowler")
        if not session["SUB_STAT"] == "Subscribed":
            return redirect(url_for("snssetup"))
        sf_sub_name = session["sub"].replace("-", "")
        data_file = os.path.join(basedir, "static/checks3.txt")
        my_checks = read_checks(data_file)
        my_regions = getRegions(server_redis)
        setup_form = SetupProwlerScan()
        setup_form.checks.choices = [(key, my_checks[key]) for key in my_checks]
        setup_form.regions.choices = my_regions
        tool_info = get_tool_info("prowler")
        role_name = tool_info["JOB"]["M"]["JOB_ROLE"]["S"]
        if setup_form.validate_on_submit():
            message = gatekeeper(session, decrement=True)
            if message:
                flash(message, "danger")
                return redirect(url_for("index"))
            t = Tools(
                "prowler",
                server_redis.get("TOOLS_ALLOWED"),
                app.config["MY_TOOL_TABLE"],
                server_redis,
            )
            sf_account = setup_form.account_id.data
            sf_account = sf_account.replace(" ", ",").replace(",,", ",").split(",")
            sf_checks = setup_form.checks.data
            sf_checks_joined = " ".join(sf_checks)
            sf_regions = setup_form.regions.data
            sf_external_id = setup_form.external_id.data
            sf_role_name = setup_form.role_name.data
            sf_bucket_role_arn = setup_form.bucket_role_arn.data
            sf_custom_bucket = setup_form.custom_bucket.data
            sf_bucket_external_id = setup_form.bucket_external_id.data
            evaluate = prowler_validate(
                sf_account,
                sf_role_name,
                sf_external_id,
                sf_bucket_role_arn,
                sf_custom_bucket,
                sf_bucket_external_id,
                setup_form.both_buckets.data,
            )
            if not isinstance(evaluate, bool):
                flash(evaluate, "danger")
                return render_template(
                    "prowler.html",
                    gridic="secondary",
                    ia=authtest,
                    setup_form=setup_form,
                    job_role=role_name,
                )
            if setup_form.both_buckets.data:
                sf_both_buckets = "0"
            else:
                sf_both_buckets = "1"
            if sf_checks:
                sf_exclude = "--compliance"
            else:
                sf_exclude = ""
            if sf_regions:
                sf_region_list = " ".join(sf_regions)
            else:
                sf_region_list = server_redis.get("MY_REGION")
            job_ids = []
            for account in sf_account:
                bs = batch_scan(
                    sf_region_list,
                    account,
                    sf_checks_joined,
                    sf_sub_name,
                    sf_exclude,
                    t,
                    sf_external_id,
                    sf_role_name,
                    sf_bucket_role_arn,
                    sf_custom_bucket,
                    sf_both_buckets,
                    sf_bucket_external_id,
                )
                if not isinstance(bs, dict):
                    break
                else:
                    bs["jobName"] = "prowler"
                    updateScans(bs)
                    job_ids.append(bs["jobId"])

            environment_list = set_env(
                session,
                server_redis,
                t,
                external_id=sf_bucket_external_id,
                external_bucket=sf_custom_bucket.lower(),
                role_arn=sf_role_name,
                both_buckets=sf_both_buckets,
            )
            my_region = server_redis.get("MY_REGION")
            fn_session = aws_session(my_region)
            container_overrides = {"environment": environment_list}
            depends_list = []
            for job_id in job_ids:
                depends_list.append({"jobId": job_id, "type": "SEQUENTIAL"})
            fn_submit_job(
                fn_session,
                "lastcontainer",
                "NoInternetQueue",
                "LastContainerDefinition",
                container_overrides,
                depends_on=depends_list,
            )
            session.pop("SESSION_ID")
            session["SESSION_ID"] = uuid.uuid4().hex
            return render_template(
                "prowler.html",
                gridic="secondary",
                ia=authtest,
                bs=bs,
                setup_form=SetupProwlerScan(formdata=None),
                job_role=role_name,
            )
        else:
            return render_template(
                "prowler.html",
                gridic="secondary",
                ia=authtest,
                setup_form=setup_form,
                job_role=role_name,
            )
    else:
        return render_template("prowler.html", gridic="secondary", ia=authtest)


@app.route("/batchstats/", methods=["GET"])
def batchstats():
    authtest = isauth(session, server_redis, app.config)
    image_list = Tools.get_images(server_redis)
    if session["BATCH_SCANS"]:
        scan_ids = json.loads(session["BATCH_SCANS"])
    else:
        scan_ids = ""
    try:
        bscan = request.args.get("bscan")
        item_found = next(item for item in scan_ids if item["jobId"] == bscan)
        if item_found:
            my_region = server_redis.get("MY_REGION")
            fn_session = aws_session(my_region)
            gbj = get_batch_jobs(fn_session, my_region, bscan)
            logstream = gbj["logStreamName"]
            my_logs = get_log_stream(fn_session, logstream)
            return render_template(
                "batchstats.html",
                gridic="secondary",
                ia=authtest,
                gbj=gbj["ResultList"][0],
                my_logs=my_logs,
                scan_ids=scan_ids,
                image_list=image_list,
            )
        else:
            gbj = False
            my_logs = False
            return render_template(
                "batchstats.html",
                gridic="secondary",
                ia=authtest,
                gbj=gbj,
                my_logs=my_logs,
                scan_ids=scan_ids,
                image_list=image_list,
            )
    except Exception:
        return render_template(
            "batchstats.html",
            gridic="secondary",
            ia=authtest,
            scan_ids=scan_ids,
            image_list=image_list,
        )


@app.route("/logout/")
def logout():
    for key in list(session.keys()):
        session.pop(key)
    session.clear()
    res = make_response(redirect(app.config["LOGOUT_URL"]))
    res.set_cookie(
        "AWSELBAuthSessionCookie-0",
        "",
        max_age=0,
        secure=True,
        httponly=True,
        samesite="Lax",
    )
    res.set_cookie(
        "AWSELBAuthSessionCookie-1",
        "",
        max_age=0,
        secure=True,
        httponly=True,
        samesite="Lax",
    )
    return res


@app.route("/download-cfn/<my_file>")
def download_file(my_file):
    if my_file == "ProwlerRole":
        path = os.path.join(basedir, "static/cft/ProwlerRole.yaml")
        if server_redis.exists("LAST_FILE_DATE"):
            last_file_date = server_redis.get("LAST_FILE_DATE")
        else:
            last_file_date = False
        redis_update = file_mod(path, last_file_date)
        if redis_update:
            server_redis.set("LAST_FILE_DATE", redis_update)
        return send_file(path, as_attachment=True)
    elif my_file == "S3BucketRole":
        path = os.path.join(basedir, "static/cft/S3BucketRole.yaml")
        return send_file(path, as_attachment=True)
    else:
        flash("You tried to download a Unicorn! It does not exist.", "danger")
        return redirect(url_for("index"))


if __name__ == "__main__":
    app.run(debug=False)
