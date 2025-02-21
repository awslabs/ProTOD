## 2023-03-06 Lee Myers
Taph
* Updated bootstrap to 5.3 to accomodate card changes
* Updated Front page to a card style

## 2022-02-13 Dom Colangelo
* Decomposed dboperations.py into dbsetup.py (setup DynamoDB table) and dboperations.py (various read/write Dynamo operatioons). Issue V830508132
* Added AWS CLI check to setup-env.sh
## 2022-02-07 Dom Colangelo
* Updated build-protod.sh
*   Query user in console for build variables
*   Dynamically fetch region, account number, ACM cert ARN, ALB log account ID
*   Run dboperations.py as part of setup
* Updated delete-infra.sh
*   Bugfix: updated path to CloudFormation files
* Updated 3.3-ProTOD-SecretManager.yaml
*   Add env vars to existing Secrets Manager secret
* Updated taph dboperations.py
*   Retrieve DynamoDB tools table name from Secrets Manager
* Updated taph secretmgr.py
*   Variable naming convention update
* Updated taph config.py
*   Retrieve env vars from Secrets Manager

## 2022-02-04 Andrea Di Fabio
* Updated README.md
* Added submit-job.sh for tersting file-scanning tools on the command line.
* Added lifecycle policy to only keep 5 images in ECR repos
* Added SecurityHub enabled on the account
* Updated gitignore for Trunk
* Fixed Taph dockerfile to run as protod user
* Added 2nd testing environment in config.py
* Moved DBOperations to boto3 session calls
* Specified regions with Dynamodb

## 2022-12 25-26 Lee Myers
Taph
* Rebuilt Tools class to grab config from Dynamodb rather than static
* Cleaned up initial config
* Created DB class to create initial database and perform DB operations
* Updated HTML templates to reflect new tool schema
* Fixed KeyError on initial startup
* Added Prowler to new tool schema
* Fixed image sizing issue

## 2022-12-15 Lee Myers and Andrea Di Fabio
Taph -- Breaking Changes for Dev
* Changed batch job names to dynamic
* Switched STS to a regional endpoint call

## 2022-12-15 Lee Myers and Andrea Di Fabio
Taph
* Added scan time to status page
* Added Scanner icon to status page
* Added Shellcheck
* Added Detect Secrets
* Changed Tools Icon to status page in header
* Set max upload files to 50

## 2022-12-09 Lee Myers
Taph
* Consolidated code for all file scanning tools (Bandit, CFNNag)
* Consolidated form code into a single form for file scanning tools
* Created new Tools class to eliminate some hardcoding
* Added Dropzone JavaScript library to simplify file/folder uploads
* Added input validation for non-existent URLs
* Created form widget for JavaScript submit button

## 2022-10-27 Andrea Di Fabio
Prowler
* Updated container to be a local AWS pull
## 2022-10 20-27 Lee Myers
Taph
* Updated prowler to v2.12.0
* Removed need for secrets by using dynamic key
* Updated Requirements versions
* Added Encryption to SNS topic creation
* Added tags to SNS topic creation
* Pushed out updated docker images
* Added LICENSES file to verify that all licenses are approved ones

## Version 0.2.5
## 2022-10-18 Andrea Di Fabio
Docker
* Added custom Bandit Dockerfile
* Added script for Bandit container to access S3
Taph
* Added a file upload form for Bandit
* Added SNS support for Bandit
* Updated Project config with CFN parameters
## 2022-10-18 Lee Myers
* Added link to Bandit scan
* Fixed bug where CFN-NAG and Bandit looped back to index

## Version 0.2.0 (Lunch and Learn Demo Release)
## 2022-09-29 Lee Myers
Docker
* Updated CFN-Nag container to use plain text output
Taph
* Added banner stating not for customer use


## 2022-09-27 Lee Myers
Docker
* Added custom CFN-NAG Dockerfile
* Added script for CFN-NAG container to access S3
Taph
* Added a file upload form for CFN-NAG
* Added a Session ID as a UUID for unique visitor sessions
* Added SNS support for CFN-NAG
* Updated Project config with CFN parameters
* Updated the FileUpload Class

## 2022-09-11 Lee Myers
Taph
* Added ability to save to custom bucket
* Added multiple account scan capability
* Added support for Flask Flash messages on errors
* Added CFN template download for Prowler role
* Added file upload class (unused currently)
* Added policy simulator for pre-flight check (unused currently)
* Cleaned up imports to modules folder
* Removed residual hard-coded values

## Version 0.1.0 (Initial Release)
## 2022-07-07 Lee Myers
Taph
* Added static folder URL setting for JS/CSS import consistency
* Added batch job scan for batch status
* Added logstream scan for batch job logs
* Added batchstats.html URL status page
* Added Select All javascript to Prowler scan page
* Added SecretsManager keys and call functions
* Added AWS ALB cookie deletion on logout
* added bootstrap.bundle.min.js.map
* Changed form checkbox render to iteration for more class control
* Changed hardcoded secret key to SecretsManager key
* Merged diagnostics page with profile page
* Removed extra icon from page header
* Removes diag page as it was merged with profile

## 2022-06-27 Lee Myers
Docker
* Updated Dockerfile to add dev file to compile cffi and cryptography modules

Python
* Updated requirements file to latest versions
* Added jwt which added cffi and cryptography modules

Taph
* Added a JWT decoder to use Cognito information
* Alias name and email are now gathered from the JWT
* Added SNS integration for topic and subscription creations
* Added JWT and SNS info to Redis session information
* Removed alias as an editable field in the Prowler scan as it is now captured from the JWT
* Added SNS Setup page

## 2022-06-19 Lee Myers
Taph
* Added CHANGES document
* Added multiple user sessions
* Added Nav icon to clear session information
* Added toggle to exclude checks
* Added Region selection to additional scan properties
* Added a Session Diagnostics Page
* Added Batch Scan IDs to Redis for Job tracking
* Changed HTML output to a toggle
* Changed additional scan properties to an accordion view for easy selections
* Changes form labels to be more descriptive
* Fixed tracking of Alias in Redis
* To Do add batch job information screen.

## 2022-06-06 Lee Myers
Taph
* I removed the stuff about role listing
* I removed user side region setting
* I moved static settings to app.config
* Created a local docker-compose for local testing
* Added redis location testing for local or container runs
* Added the Prowler checks file and function to parse it
* Made the launch string for prowler dynamically built
* Added the Checks to an optional checkbox section that uses a dropdown
* Removed the extra icons at the top of the pages
* Added alias so that the output file is customized
* Added some input validation
* Updated bootstrap and added jquery
* Added a coming soon CFN_NAG page