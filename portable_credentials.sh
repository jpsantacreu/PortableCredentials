#!/usr/bin/env bash
#
# Portable Credentials
#
# Copyright (C) 2018 Juan Pablo Santacreu <juanpablo.santacreu@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#

#Script must be launched with argument
if [[ $# -eq 0 ]]; then
  echo "No arguments supplied: ./`basename "$0"` [upload|download]"
  exit 1
fi

# Default portable credentials configuration file
CONFIG_FILE=~/.portable_credentials

# Default ssh configuration
SSH_CONFIG_FILE=.ssh/config_portable
DEFAULT_CERT_DIRECTORY=.ssh/certificates/

# Temp files
TMP_PATH=/tmp
TMP_FILE_COMPRESSED=ssh-config.tar.gz
TMP_FILE_COMPRESSED_ENCRYPTED=$TMP_FILE_COMPRESSED.gpg
RESPONSE_FILE=$TMP_PATH/tmp_response

# Grep needed
if [[ $GREP_BIN == "" ]]; then
    BIN_DEPS="$BIN_DEPS grep"
    GREP_BIN="grep"
fi

# Sed needed
if [[ $SED_BIN == "" ]]; then
    BIN_DEPS="$BIN_DEPS sed"
    SED_BIN="sed"
fi

# Gpg needed
if [[ $GPG_BIN == "" ]]; then
    BIN_DEPS="$BIN_DEPS gpg"
    GPG_BIN="gpg"
fi

# Tar needed
if [[ $TAR_BIN == "" ]]; then
    BIN_DEPS="$BIN_DEPS tar"
    TAR_BIN="tar"
fi

# Curl needed
if [[ $CURL_BIN == "" ]]; then
    BIN_DEPS="$BIN_DEPS curl"
    CURL_BIN="curl"
fi

# Dependencies check
which $BIN_DEPS > /dev/null
if [[ $? != 0 ]]; then
    for i in $BIN_DEPS; do
        which $i > /dev/null ||
            NOT_FOUND="$i $NOT_FOUND"
    done
    echo -e "Error: Required program could not be found: $NOT_FOUND"
    exit 1
fi

# Remove temporary files
function remove_temp_files
{
    if [[ $DEBUG == 0 ]]; then
        rm -fr "$RESPONSE_FILE"
        rm -fr "$CHUNK_FILE"
        rm -fr "$TEMP_FILE"
    fi
    rm -fr "$TMP_PATH/$TMP_FILE_COMPRESSED"
    rm -fr "$TMP_PATH/$TMP_FILE_COMPRESSED_ENCRYPTED"
}

# Check the curl exit code
function check_http_response
{
    CODE=$?

    # Checking curl exit code
    case $CODE in
        # OK
        0)
        ;;
        # Proxy error
        5)
            print "\nError: Couldn't resolve proxy. The given proxy host could not be resolved.\n"
            remove_temp_files
            exit 1
        ;;
        # Missing CA certificates
        60|58|77)
            print "\nError: cURL is not able to performs peer SSL certificate verification.\n"
            print "Please, install the default ca-certificates bundle.\n"
            print "To do this in a Debian/Ubuntu based system, try:\n"
            print "  sudo apt-get install ca-certificates\n\n"
            print "If the problem persists, try to use the -k option (insecure).\n"
            remove_temp_files
            exit 1
        ;;
        6)
            print "\nError: Couldn't resolve host.\n"
            remove_temp_files
            exit 1
        ;;
        7)
            print "\nError: Couldn't connect to host.\n"
            remove_temp_files
            exit 1
        ;;
    esac

    # Checking response file for generic errors
    if grep -q "HTTP/1.1 400" "$RESPONSE_FILE"; then
        ERROR_MSG=$(sed -n -e 's/{"error": "\([^"]*\)"}/\1/p' "$RESPONSE_FILE")
        case $ERROR_MSG in
             *access?attempt?failed?because?this?app?is?not?configured?to?have*)
                echo -e "\nError: The Permission type/Access level configured doesn't match the DropBox App settings!\nPlease run \"$0 unlink\" and try again."
                exit 1
            ;;
        esac
    fi
}

# Compress ssh config and certifies
function compress_data
{
  $TAR_BIN zcfv $TMP_PATH/$TMP_FILE_COMPRESSED -C ~ $SSH_CONFIG_FILE $CERTS_DIRECTORY #> /dev/null 2>&1
}

# Encrypt compress file
function encrypt_file
{
  echo $GPG_PASSPHRASE | $GPG_BIN --output $TMP_PATH/$TMP_FILE_COMPRESSED_ENCRYPTED --passphrase-fd 0 -c $TMP_PATH/$TMP_FILE_COMPRESSED > /dev/null 2>&1
}

# Discover backend for upload
function db_upload
{
  case $BACKEND in
    "Dropbox")
      db_upload_dropbox
    ;;
    "AWS S3")
      echo -ne "Backend not implemented yet\n"
      exit 1
    ;;
    "Google Drive")
      echo -ne "Backend not implemented yet\n"
      exit 1
    ;;
    "ownCloud")
      echo -ne "Backend not implemented yet\n"
      exit 1
    ;;
    *)
      echo -ne "Backend not recognized\n"
      exit 1
    ;;
  esac;
  remove_temp_files
}

# Upload to dropbox backend
function db_upload_dropbox
{
    $CURL_BIN -k --progress-bar -X POST -i --globoff -o "$RESPONSE_FILE" --header "Authorization: Bearer $OAUTH_ACCESS_TOKEN" --header "Dropbox-API-Arg: {\"path\": \"/$TMP_FILE_COMPRESSED_ENCRYPTED\",\"mode\": \"overwrite\",\"autorename\": true,\"mute\": false}" --header "Content-Type: application/octet-stream" --data-binary @"$TMP_PATH/$TMP_FILE_COMPRESSED_ENCRYPTED" https://content.dropboxapi.com/2/files/upload
    check_http_response

    #Check
    if grep -q "^HTTP/1.1 200 OK" "$RESPONSE_FILE"; then
        echo -ne "Ssh configuration and credentials uploaded\n"
    else
        echo -ne "FAILED\n"
        echo -ne "An error occurred requesting /upload\n"
        ERROR_STATUS=1
    fi
}

# Discover backend for download
function db_download
{
  case $BACKEND in
    "Dropbox")
      db_download_dropbox
    ;;
    "AWS S3")
      echo -ne "Backend not implemented yet\n"
      exit 1
    ;;
    "Google Drive")
      echo -ne "Backend not implemented yet\n"
      exit 1
    ;;
    "ownCloud")
      echo -ne "Backend not implemented yet\n"
      exit 1
    ;;
    *)
      echo -ne "Backend not recognized\n"
      exit 1
    ;;
  esac;
}

# Download to dropbox backend
function db_download_dropbox
{
    $CURL_BIN -k -L -s -X POST --globoff -D "$RESPONSE_FILE" -o "$TMP_PATH/$TMP_FILE_COMPRESSED_ENCRYPTED" --header "Authorization: Bearer $OAUTH_ACCESS_TOKEN" --header "Dropbox-API-Arg: {\"path\": \"/$TMP_FILE_COMPRESSED_ENCRYPTED\"}" https://content.dropboxapi.com/2/files/download
    check_http_response

    #Check
    if grep -q "^HTTP/1.1 200 OK" "$RESPONSE_FILE"; then
        echo -ne "Ssh configuration and credentials downloaded\n"
        echo -ne "For ssh auto-complete execute: source /etc/bash_completion.d/autocomplete_portable\n"
    else
        echo -ne "FAILED\n"
        rm -fr "$TMP_PATH/$TMP_FILE_COMPRESSED_ENCRYPTED"
        ERROR_STATUS=1
        return
    fi
}

# Decrypt compress file
function decrypt_file
{
  echo $GPG_PASSPHRASE | $GPG_BIN -q --output $TMP_PATH/$TMP_FILE_COMPRESSED --passphrase-fd 0 $TMP_PATH/$TMP_FILE_COMPRESSED_ENCRYPTED
}

# Descompress ssh config and certifies
function decompress_data
{
  $TAR_BIN zxf $TMP_PATH/$TMP_FILE_COMPRESSED -C ~ $SSH_CONFIG_FILE > /dev/null 2>&1
  $TAR_BIN zxf $TMP_PATH/$TMP_FILE_COMPRESSED -C ~ $CERTS_DIRECTORY > /dev/null 2>&1

  remove_temp_files
}

# Set include parameter in ssh config
function set_include
{
  $GREP_BIN $SSH_CONFIG_FILE ~/.ssh/config
  if [[ $? != 0 ]]; then
    echo "Include ~/$SSH_CONFIG_FILE" >> ~/.ssh/config
  fi
}

# Reconfigure ssh if dont use default config
function ssh_reconfigure
{
  SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
  /usr/bin/sudo /bin/cp $SCRIPTPATH/autocomplete_portable /etc/bash_completion.d/
}

################
#### SETUP  ####
################

# Checking for auth file
if [[ -e $CONFIG_FILE ]]; then

    # Loading data
    source "$CONFIG_FILE" 2>/dev/null || {
        $SED_BIN -i'' 's/:/=/' "$CONFIG_FILE" && source "$CONFIG_FILE" 2>/dev/null
    }
    # Checking loaded data
    if [[ $CERTS_DIRECTORY = "" ]] || [[ $GPG_PASSPHRASE = "" ]] || [[ $BACKEND = "" ]] || [[ $OAUTH_ACCESS_TOKEN = "" ]] ; then
        echo -ne "Error loading data from $CONFIG_FILE...\n"
        echo -ne "It is recommended to run $0 unlink\n"
        remove_temp_files
        exit 1
    fi

# First execution
else

    echo -ne "\n This is the first time you run this script, please insert following data:\n\n"

    echo -ne " # Directory of certificates [$DEFAULT_CERT_DIRECTORY]: "
    read -r -e -i "$DEFAULT_CERT_DIRECTORY" CERTS_DIRECTORY

    echo -ne " # Gpg passphrase to securize credential files: "
    read -r GPG_PASSPHRASE

    echo -ne " # Select backend to store credentials (only Dropbox is available):\n"
    PS3="Choose an option: "
    OPTIONS=("Dropbox" "AWS S3" "Google Drive" "ownCloud")
    select BACKEND in "${OPTIONS[@]}"
    do
      case $BACKEND in
        "Dropbox")
          echo -ne " # Dropbox Access token: "
          read -r OAUTH_ACCESS_TOKEN
          break
          ;;
        "AWS S3")
          echo -ne "Actually only dropbox backend are available\n"
          ;;
        "Google Drive")
          echo -ne "Actually only dropbox backend are available\n"
          ;;
        "ownCloud")
          echo -ne "Actually only dropbox backend are available\n"
          ;;
        *)
          echo -ne "Invalid option\n"
          ;;
      esac
    done

    echo -ne "\n > Looks ok? [y/N]: "
    read -r answer
    if [[ $answer != "y" ]]; then
        remove_temp_files
        exit 1
    fi

    echo "CERTS_DIRECTORY=$CERTS_DIRECTORY" >> "$CONFIG_FILE"
    echo "GPG_PASSPHRASE=$GPG_PASSPHRASE" >> "$CONFIG_FILE"
    echo "BACKEND=$BACKEND" >> "$CONFIG_FILE"
    echo "OAUTH_ACCESS_TOKEN=$OAUTH_ACCESS_TOKEN" >> "$CONFIG_FILE"
    echo "   Configuration has been saved."

    remove_temp_files
    set_include
fi

################
#### START  ####
################

ARGUMENT=${*:$OPTIND:1}

# Checking params values
case $ARGUMENT in
    upload)
	compress_data
        encrypt_file
        db_upload
    ;;
    download)
        db_download
        decrypt_file
        decompress_data
	ssh_reconfigure
    ;;
    *)
        if [[ $ARGUMENT != "" ]]; then
            print "Error: Unknown argument: $ARGUMENT\n\n"
            ERROR_STATUS=1
        fi
    ;;
esac

remove_temp_files

if [[ $ERROR_STATUS -ne 0 ]]; then
    echo "Some error occured. Please check the log."
fi

exit $ERROR_STATUS
