# PortableCredentials
Access your ssh settings and your credentials wherever you want

Upload your ssh file and your certificates to the cloud

Note: Actually only support uploads to Dropbox

## First run
In the first execution the configuration is launched. You will need to indicate:
- The ssh configuration file. By default it is .ssh / config
- The directory where the certificates you want to upload are located. By default it is .ssh / certificates /
- A passphrase (which you must remember) with which the set of files will be encrypted
- The backend to use. Currently it only supports Dropbox
- The OAUTH_ACCESS_TOKEN corresponding to your Dropbox account

## Run it
Once configured the execution syntax is:
source portable_credentials.sh [upload | download]

- Upload option: compress, encrypt and upload your data to cloud
- Download option: Download, decrypt and decompress your data
