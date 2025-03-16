#!/bin/bash
#
# toggles ssh listening only on my tailnet
# (as opposed to public facing ip)
#
# makes use of environment vars TAILIP, SHCONFD, for substition
# in order to first backup config, then replace the listen address
# in the active config, and finally restart ssh server.
# 
# author: Matthew Forrester Wolffe, 2024.12
#
# NOTE: put under VCS 2025.03
# TODO: idk the regexes work but they are awful lol
#

#
# getouttta heeeya
#
if [[ -z "$TAILIP" ]]; then
	printf "Are you mfw?\nOh, okay lol, just don't forget the env vars\n" >&2
	exit 1
fi

#
# NOTE: the fallback if no environment var for config file
# NOTE: idk if I want to do this like this really
# TODO: automate backup deletions
#
CONFIG="${SHCONFD:-/etc/ssh/sshd_config}"
BACKUP="${CONFIG}.bak.$(date +%F-%T)"

#
# again? get outttttta heeeeya
#
if [[ $EUID -ne 0 ]]; then
	printf "\nAre you, mfw, a root?\nOh, okay, lol, just don't forget to run as root" >&2
	exit 1
fi

#
# make the backup
#
cp "${CONFIG}" "${BACKUP}"
echo "Backed up config."

#
# TODO: @mfwolffe agnostic?
#
current_addr=$(grep -E "^ListenAddress[[:space:]]+$TAILIP" "$CONFIG")

#
# TODO: @mfwolffe also agnostic?
# 
# if [[ $current_addr == "ListenAddress $TAILIP "]]; then
# sed -i -E "s/^ListenAddress[[:space:]]+$TAILIP/#ListenAddress $TAILIP/" "$CONFIG"
# echo "Reverted (commented out, lol) tailnet"
# else
# 	sed -i -E "s/^(ListenAddress.*)/#\1/" "$CONFIG"
# fi

#
# NOTE: yea, it's ugly.
#
# NOTE: CONTROL FLOW:
#				check if there's an active listening addr in the config file
#					then listen outside of tailnet
#					ie, comment it out lol
#				Otherwise:
# 					if there's already this field in the config:
#           replace it,
# 					Otherwise:
#             throw it on the end of the file.
#
if grep -qE "^[[:space:]]*ListenAddress[[:space:]]+$TAILIP[[:space:]]*$" "$CONFIG"; then
  sed -i -E "s/^[[:space:]]*ListenAddress[[:space:]]+$TAILIP[[:space:]]*$/# ListenAddress $TAILIP/" "$CONFIG"
  printf "\nToggledTailAndUnRan: Public Access Restored.\n"
else
  if grep -qE "^[[:space:]]*#?[[:space:]]*ListenAddress" "$CONFIG"; then
    sed -i -E "s|^[[:space:]]*#?[[:space:]]*ListenAddress.*|ListenAddress $TAILIP|" "$CONFIG"
  else
    echo "ListenAddress $TAILIP" >> "$CONFIG"
  fi
  printf "\nToggledTailAndRan: Restricted access to tailnet.\n"
fi

#
# NOTE: that is a `d`; this is not the
#		same -T for PTY no alloc
#		
if ! sshd -T >/dev/null 2>&1; then
  echo "oh matt."
  cp "$BACKUP" "$CONFIG"
  exit 1
fi

systemctl reload sshd && echo "Success."  || echo "Failure."

