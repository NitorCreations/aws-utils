#!/bin/bash

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

COMPRESSOR_JAR="yuicompressor-2.4.8.jar"

if ! [ -r $COMPRESSOR_JAR ]; then
  wget -O $COMPRESSOR_JAR https://github.com/yui/yuicompressor/releases/download/v2.4.8/$COMPRESSOR_JAR
fi

for next in "$@"; do
  OUT="${next%*.js}.min.js"
  java -jar $COMPRESSOR_JAR --type js --nomunge -o $OUT $next
  sed -i -e 's/var\s*CF_\([^;]*\);/\nvar CF_\1;\n/g' -e 's/\n\n/\n/g' $OUT
done
