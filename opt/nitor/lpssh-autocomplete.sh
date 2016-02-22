# Copyright 2016 Nitor Creations Oy
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

_lpssh() {
  COMPREPLY=()
  cur=${COMP_WORDS[$COMP_CWORD]}
  prev=${COMP_WORDS[$(($COMP_CWORD - 1 ))]}
  if [ "$cur" = "-" ]; then
    COMPREPLY[0]="-k"
    return 0
  fi
  case $prev in
    lpssh)
      TMP=$(mktemp)
      if ! lpass show --notes my-ssh-mappings > $TMP; then
           echo "Could not get mapings"
           rm -f $TMP
           return 1
      fi
      COMPREPLY=( $(compgen -W "-k $(cat $TMP | cut -d ":" -f1)" -- "$cur") )
      rm -f $TMP
      ;;
    -k)
      COMPREPLY=( $(compgen -W "$(lpass ls | egrep '\.rsa\W|\.pem\W' | awk -NF '/|\\ ' '{ print $2 }' | sort -u)" -- "$cur") )
      ;;
  esac
}

complete -F _lpssh lpssh
