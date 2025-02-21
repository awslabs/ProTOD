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
from flask_wtf import FlaskForm
from markupsafe import Markup
from wtforms import (
    BooleanField,
    RadioField,
    SelectMultipleField,
    StringField,
    SubmitField,
    widgets,
)
from wtforms.validators import DataRequired, Length, Optional


class ButtonWidget(object):
    """
    Renders a multi-line text area.
    `rows` and `cols` ought to be passed as keyword args when rendering.
    """

    input_type = "submit"

    html_params = staticmethod(widgets.html_params)

    def __call__(self, field, **kwargs):
        kwargs.setdefault("id", field.id)
        kwargs.setdefault("type", self.input_type)
        if "value" not in kwargs:
            kwargs["value"] = field._value()

        # This HTML return is for a button widget. Escaping the markup changes the < > / values to encoded and renders a string rather than a button.
        # nosemgrep: explicit-unescape-with-markup
        return Markup(
            "<button {params}>{label}</button>".format(
                params=self.html_params(name=field.name, **kwargs),
                label=field.label.text,
            )
        )


class ButtonField(StringField):
    widget = ButtonWidget()


class MultiCheckboxField(SelectMultipleField):
    widget = widgets.ListWidget(prefix_label=False)
    option_widget = widgets.CheckboxInput()


class SetupProwlerScan(FlaskForm):
    """Creates a form for Prowler scan settings"""

    account_id = StringField(
        "Enter the accounts you would like to scan. Comma or space separated for multiple accounts (10 accounts Max).",
        [
            DataRequired(),
            Length(
                min=12,
                max=140,
                message=("Please enter the 12 digit account number."),
            ),
        ],
    )
    external_id = StringField(
        "Enter the external ID for the scan. All accounts above must use the same external ID or scanned separately.",
        [
            DataRequired(),
            Length(
                min=10,
                max=256,
                message=("Please enter the external ID for the scan."),
            ),
        ],
    )
    role_name = StringField(
        "Enter the role name for the scan if changed from default. All accounts above must use the same role name or scanned separately.",
        [
            DataRequired(),
            Length(
                min=10,
                max=64,
                message=("Please enter the role name."),
            ),
        ],
    )
    custom_bucket = StringField(
        "Enter custom output bucket. Note: Multiple account scans will use the same bucket and same external ID or scanned separately."
    )
    bucket_role_arn = StringField(
        "Enter the role ARN with permissions to the custom upload bucket.",
        [
            Optional(),
            Length(
                min=10,
                max=128,
                message=("Please enter the role ARN."),
            ),
        ],
    )
    bucket_external_id = StringField(
        "Enter the external ID for the output bucket.",
        [
            Optional(),
            Length(
                min=10,
                max=256,
                message=("Please enter the external ID for the output bucket."),
            ),
        ],
    )
    both_buckets = BooleanField(
        "Toggle to send output to custom bucket and ProTOD bucket.", [Optional()]
    )
    regions = MultiCheckboxField("Regions to be included in the scan.", coerce=str)

    checks = MultiCheckboxField("Custom Checks", coerce=str)

    submit = SubmitField("Submit")


class DragDropScan(FlaskForm):
    """Creates a generic form for Drag and Drop Scans"""

    external_id = StringField(
        "Enter the external ID for the custom upload bucket.",
        [
            Optional(),
            Length(
                min=10,
                max=256,
                message=(
                    "Please enter the external ID for the custom upload bucket role."
                ),
            ),
        ],
    )
    role_arn = StringField(
        "Enter the role ARN with permissions to the custom upload bucket.",
        [
            Optional(),
            Length(
                min=10,
                max=128,
                message=("Please enter the role ARN."),
            ),
        ],
    )
    custom_bucket = StringField("Enter custom output bucket.", [Optional()])
    both_buckets = BooleanField(
        "Toggle to send output to custom bucket and ProTOD bucket.", [Optional()]
    )
    # use_ai = BooleanField(
    #     "Toggle to have Amazon Bedrock AI analyze your files and make recommendations",
    #     [Optional()],
    # )
    ai_radio = RadioField(
        "Use AI from Amazon Bedrock to analyze my file.",
        choices=[
            ("0", "None"),
            ("1", "Generate a threat model"),
            ("2", "Find vulnerabilities and make recommendations"),
            ("3", "Document my code"),
        ],
        default="0",
    )
    submit = ButtonField()


class MultiScan(FlaskForm):
    """Creates a generic form for Drag and Drop Scans"""

    external_id = StringField(
        "Enter the external ID for the custom upload bucket.",
        [
            Optional(),
            Length(
                min=10,
                max=256,
                message=(
                    "Please enter the external ID for the custom upload bucket role."
                ),
            ),
        ],
    )
    role_arn = StringField(
        "Enter the role ARN with permissions to the custom upload bucket.",
        [
            Optional(),
            Length(
                min=10,
                max=128,
                message=("Please enter the role ARN."),
            ),
        ],
    )
    custom_bucket = StringField("Enter custom output bucket.", [Optional()])
    both_buckets = BooleanField(
        "Toggle to send output to custom bucket and ProTOD bucket.", [Optional()]
    )
    checks = MultiCheckboxField("Tools To Scan With", [DataRequired()], coerce=str)
    submit = ButtonField()
