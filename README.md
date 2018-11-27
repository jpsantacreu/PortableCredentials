# PortableCredentials
Access to your ssh config file and your credentials wherever you are

Upload/download ssh configuration file (~/.ssh/config_portable) and yours certificates to cloud (currently only supports Dropbox backend)

## Run it
Execution syntax:
./portable_credentials.sh [ upload | download ]

- Upload option: compress, encrypt and upload your data to backend selected
- Download option: Download, decrypt and decompress your data from backend selected

Note: script run with the ssh configuration file '~/.ssh/config_portable'

## First run
In the first execution, auto-configuration is launched. Script will ask you:
- Directory where your certificates are located. By default .ssh/certificates/
- A passphrase (you must remember it) to encrypt ssh configuration file and certificates directory
- Backend to store ssh configuration file and certificate directory. Currently only supports Dropbox
- OAUTH_ACCESS_TOKEN corresponding to your Dropbox account (create an app in https://www.dropbox.com/developers/apps and generate OAUTH2 Access Token)
