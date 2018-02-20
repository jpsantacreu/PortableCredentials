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

#Script must be launched with source to alias use
if [[ $_ == $0 ]]; then
  echo "Script must be sourced: source `basename \"$0\"` [upload|download]"
  exit 1
fi

#Default portable credentials configuration file
CONFIG_FILE=~/.portable_credentials

#Default ssh configuration
DEFAULT_SSH_CONFIG=.ssh/config
DEFAULT_CERT_DIRECTORY=.ssh/certificates/

#Ssh config file consolidated
SSH_CONFIG_CONSOLIDATED=~/.ssh/config_consolidated

#Temp files
TMP_PATH=/tmp
TMP_FILE_COMPRESSED=ssh-config.tar.gz
TMP_FILE_COMPRESSED_ENCRYPTED=$TMP_FILE_COMPRESSED.gpg
RESPONSE_FILE=$TMP_PATH/tmp_response

#Sed needed
if [[ $SED_BIN == "" ]]; then
    BIN_DEPS="$BIN_DEPS sed"
    SED_BIN="sed"
fi

#Gpg needed
if [[ $GPG_BIN == "" ]]; then
    BIN_DEPS="$BIN_DEPS gpg"
    GPG_BIN="gpg"
fi

#Tar needed
if [[ $TAR_BIN == "" ]]; then
    BIN_DEPS="$BIN_DEPS tar"
    TAR_BIN="tar"
fi

#Curl needed
if [[ $CURL_BIN == "" ]]; then
    BIN_DEPS="$BIN_DEPS curl"
    CURL_BIN="curl"
fi

#Dependencies check
which $BIN_DEPS > /dev/null
if [[ $? != 0 ]]; then
    for i in $BIN_DEPS; do
        which $i > /dev/null ||
            NOT_FOUND="$i $NOT_FOUND"
    done
    echo -e "Error: Required program could not be found: $NOT_FOUND"
    exit 1
fi

#Remove temporary files
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

#Check the curl exit code
function check_http_response
{
    CODE=$?

    #Checking curl exit code
    case $CODE in
        #OK
        0)
        ;;
        #Proxy error
        5)
            print "\nError: Couldn't resolve proxy. The given proxy host could not be resolved.\n"
            remove_temp_files
            exit 1
        ;;
        #Missing CA certificates
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

    #Checking response file for generic errors
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

#Compress ssh config and certifies
function compress_data
{
  $TAR_BIN zcfv $TMP_PATH/$TMP_FILE_COMPRESSED -C ~ $SSH_CONFIG_FILE $CERTS_DIRECTORY #> /dev/null 2>&1
}

#Encrypt compress file
function encrypt_file
{
  echo $GPG_PASSPHRASE | $GPG_BIN --output $TMP_PATH/$TMP_FILE_COMPRESSED_ENCRYPTED --passphrase-fd 0 -c $TMP_PATH/$TMP_FILE_COMPRESSED > /dev/null 2>&1
}

#Discover backend for upload
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
    esac
  remove_temp_files
}

#Upload to dropbox backend
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

#Discover backend for download
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
    esac
}

#Download to dropbox backend
function db_download_dropbox
{
    $CURL_BIN -k -L -s -X POST --globoff -D "$RESPONSE_FILE" -o "$TMP_PATH/$TMP_FILE_COMPRESSED_ENCRYPTED" --header "Authorization: Bearer $OAUTH_ACCESS_TOKEN" --header "Dropbox-API-Arg: {\"path\": \"/$TMP_FILE_COMPRESSED_ENCRYPTED\"}" https://content.dropboxapi.com/2/files/download
    check_http_response

    #Check
    if grep -q "^HTTP/1.1 200 OK" "$RESPONSE_FILE"; then
        echo -ne "Ssh configuration and credentials downloaded\n"
    else
        echo -ne "FAILED\n"
        rm -fr "$TMP_PATH/$TMP_FILE_COMPRESSED_ENCRYPTED"
        ERROR_STATUS=1
        return
    fi
}

#Decrypt compress file
function decrypt_file
{
  echo $GPG_PASSPHRASE | $GPG_BIN -q --output $TMP_PATH/$TMP_FILE_COMPRESSED --passphrase-fd 0 $TMP_PATH/$TMP_FILE_COMPRESSED_ENCRYPTED
}

#Descompress ssh config and certifies
function decompress_data
{
  $TAR_BIN zxf $TMP_PATH/$TMP_FILE_COMPRESSED -C ~ $SSH_CONFIG_FILE > /dev/null 2>&1
  $TAR_BIN zxf $TMP_PATH/$TMP_FILE_COMPRESSED -C ~ $CERTS_DIRECTORY > /dev/null 2>&1

  remove_temp_files
}

#Reconfigure ssh if dont use default config
function ssh_reconfigure
{
  #Delete previous alias
  alias | grep ssh
  if [[ $? == 0 ]]; then
    unalias ssh
  fi

  #if select diferent ssh config file
  if [[ $SSH_CONFIG_FILE != $DEFAULT_SSH_CONFIG ]];then
    cat ~/$DEFAULT_SSH_CONFIG $SSH_CONFIG_FILE > $SSH_CONFIG_CONSOLIDATED 
    alias ssh="ssh -F $SSH_CONFIG_CONSOLIDATED"
  fi

  # Autocomplete ssh with .ssh/config entrys
  _ssh() 
  {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts=$(grep '^Host' ~/$DEFAULT_SSH_CONFIG ~/$SSH_CONFIG_FILE | awk '{print $2}')
    COMPREPLY=( $(compgen -W "$opts" -- ${cur}) )
      return 0
  }
  complete -F _ssh ssh

  # Autocomplete scp with .ssh/config entrys
  _scp() 
  {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts=$(grep '^Host' ~/$DEFAULT_SSH_CONFIG ~/$SSH_CONFIG_FILE | awk '{print $2}')
    COMPREPLY=( $(compgen -W "$opts" -- ${cur}) )
      return 0
  }
  complete -F _scp scp

}

################
#### SETUP  ####
################

#CHECKING FOR AUTH FILE
if [[ -e $CONFIG_FILE ]]; then

    #Loading data
    source "$CONFIG_FILE" 2>/dev/null || {
        $SED_BIN -i'' 's/:/=/' "$CONFIG_FILE" && source "$CONFIG_FILE" 2>/dev/null
    }
    #Checking loaded data
    if [[ $SSH_CONFIG_FILE = "" ]] || [[ $CERTS_DIRECTORY = "" ]] || [[ $GPG_PASSPHRASE = "" ]] || [[ $BACKEND = "" ]] || [[ $OAUTH_ACCESS_TOKEN = "" ]] ; then
        echo -ne "Error loading data from $CONFIG_FILE...\n"
        echo -ne "It is recommended to run $0 unlink\n"
        remove_temp_files
        exit 1
    fi

#NEW SETUP...
else

    echo -ne "\n This is the first time you run this script, please insert following data:\n\n"

    echo -ne " # Ssh configuration file [$DEFAULT_SSH_CONFIG]: "
    read -r -e -i "$DEFAULT_SSH_CONFIG" SSH_CONFIG_FILE

    echo -ne " # Directory of certificates [$DEFAULT_CERT_DIRECTORY]: "
    read -r -e -i "$DEFAULT_CERT_DIRECTORY" CERTS_DIRECTORY

    echo -ne " # Gpg passphrase to securize credential files: "
    read -r GPG_PASSPHRASE

    echo -ne " # Select backend to store credentials (for now only dropbox):\n"
    PS3="Choose an option: "
    OPTIONS=("Dropbox" "AWS S3" "Google Drive" "ownCloud")
    select OPT in "${OPTIONS[@]}"
    do
      case $OPT in
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

    echo "SSH_CONFIG_FILE=$SSH_CONFIG_FILE" >> "$CONFIG_FILE"
    echo "CERTS_DIRECTORY=$CERTS_DIRECTORY" >> "$CONFIG_FILE"
    echo "GPG_PASSPHRASE=$GPG_PASSPHRASE" >> "$CONFIG_FILE"
    echo "BACKEND=$OPT" >> "$CONFIG_FILE"
    echo "OAUTH_ACCESS_TOKEN=$OAUTH_ACCESS_TOKEN" >> "$CONFIG_FILE"
    echo "   Configuration has been saved."

    remove_temp_files
fi

################
#### START  ####
################

COMMAND=${*:$OPTIND:1}
ARG1=${*:$OPTIND+1:1}
ARG2=${*:$OPTIND+2:1}

let argnum=$#-$OPTIND

#CHECKING PARAMS VALUES
case $COMMAND in
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
        if [[ $COMMAND != "" ]]; then
            print "Error: Unknown command: $COMMAND\n\n"
            ERROR_STATUS=1
        fi

    ;;

esac

remove_temp_files

if [[ $ERROR_STATUS -ne 0 ]]; then
    echo "Some error occured. Please check the log."
fi

#exit $ERROR_STATUS
