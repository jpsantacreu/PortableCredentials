# PortableCredentials
Access to your ssh config file and your credentials wherever you are

Upload/download ssh configuration file (~/.ssh/config_portable) and yours certificates to the cloud (actually only support Dropbox backend)

## Run it
The execution syntax is:
./portable_credentials.sh [ upload | download ]

- Upload option: compress, encrypt and upload your data to cloud selected
- Download option: Download, decrypt and decompress your data from backend cloud selected

## First run
In the first execution, auto-configuration is launched. You will need to indicate:
- Directory where your certificates are located. By default it is .ssh/certificates/
- A passphrase (you must remember it) to encrypt ssh configuration file and certificates directory
- Backend to store ssh configuration file and certificate directory. Currently only supports Dropbox
- OAUTH_ACCESS_TOKEN corresponding to your Dropbox account
