#!/usr/bin/env bash
# Copyright (c) 2018-2025 curoky(cccuroky@gmail.com).
#
# This file is part of devspace.
# See https://github.com/curoky/devspace for further info.
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
set -xeuo pipefail

abspath=$(cd "$(dirname "$0")" && pwd)

mkdir -p /opt/podmanx/
rm -rf /opt/podmanx/bin /opt/podmanx/conf /opt/podmanx/libexec
cp -r $abspath/../bin $abspath/../conf $abspath/../libexec /opt/podmanx/
chmod -R +w /opt/podmanx/bin /opt/podmanx/conf /opt/podmanx/libexec

mkdir -p /etc/systemd/system/
rm -rf /etc/systemd/system/podmanxd.service
cp $abspath/../conf/podmanxd.service /etc/systemd/system/podmanxd.service

systemctl daemon-reload
systemctl enable podmanxd.service
systemctl start podmanxd.service
systemctl status podmanxd.service

chmod +777 /tmp/podmanxd.sock

# echo 'nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml'
