#!/bin/bash

function approval()
{
cat <<EOF
## Copyright 2016 BroadSoft Inc
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
## 
##     http://www.apache.org/licenses/LICENSE-2.0
## 
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.

EOF

yn="no"
printf "%s" "Do you accept this license? (enter \"yes\") "
read yn
if [ "$yn" != "yes" ]
then
    echo "exiting."
    exit
fi
yn="no"

cat <<EOF

WARNING: this software runs with administrator privileges and will
attempt to install software from your distribution's software 
repository and from the Perl CPAN.

EOF

printf "%s" "Proceed? (enter \"yes\") "
read yn
if [ "$yn" != "yes" ]
then
    echo "exiting."
    exit
fi

echo "proceeding..."
}

YUMC="yum -y "
CPANC="cpan"
DEBUG=0

while getopts ":d" opt; do
    case ${opt} in
        d ) 
        YUMC="echo debug: yum -y "
        CPANC="echo debug: cpan"
        DEBUG=1
        ;;
        \? ) echo "Usage: cmd [-d]"
        ;;
    esac
done
shift $((OPTIND -1))

export PERL_MM_USE_DEFAULT=1
export PERL_EXTUTILS_AUTOINSTALL="--defaultdeps"


## yum packages to install
read -r -d '' YUMS <<EOF 
gcc
openssl-devel
perl-Test-*
EOF

## Perl module direct dependencies 
read -r -d '' CPANMIN <<EOF 
JSON
Carp
Text::CSV
Data::Dumper
Expect
File::Basename
File::Copy
FindBin
Time::Local
Class::Singleton
Search::Elasticsearch
EOF

## Some other Perl modules you need if you are building
read -r -d '' CPANS <<EOF 
IO::Socket::SSL
YAML
Net::SSLeay
EOF

CPANS="${CPANS} ${CPANMIN}"
YUMMODS=$CPANS

function basicyum ()
{
    $YUMC install $YUMS
}


function installCpan()
{
    $YUMC install perl-CPAN
}

function bootstrapcpan()
{
    $CPANC <<EOF
yes
EOF
    $CPANC <<EOF
o conf prerequisites_policy follow
o conf commit
EOF
}

function cpan1 () 
{
    yes yes | $CPANC -i "$1"
}


function cpanbuildcheck()
{
    dryrun=${1}
    dryrun=${dryrun:=0}
    bail=0
    which gcc
    if [ $? -ne 0 ]; then
        bail=1
        echo "missing gcc"
        echo "try: sudo yum install gcc"
    fi
    which cpan
    if [ $? -ne 0 ]; then
        bail=1
        echo missing 'cpan'
        echo "try: sudo yum install perl-CPAN"
    fi
    if [ $bail -eq 0 ]; then
        echo "found all required for CPAN building."
    else
        echo "*** missing required packages for building with CPAN"
        if [ $dryrun -eq 0 ]; then
            exit
        else
            echo continuing ...
        fi
    fi
}

MODS2=""

for i in $YUMMODS; do
    MODS2="${MODS2} perl(${i})" 
done

function install() 
{
    approval
    installCpan
    basicyum
    $YUMC install $MODS2
    bootstrapcpan

    for pmod in $CPANS; do
        perl -e "use ${pmod};" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            cpan1 $pmod
        else
            echo $pmod already installed.
        fi
    done
}

# function mincpan ()
# {
#
#     cpanbuildcheck $DEBUG
#     for pmod in $CPANMIN; do
#         perl -e "use ${pmod};" > /dev/null 2>&1
#         if [ $? -ne 0 ]; then
#             cpan1 $pmod
#         else
#             echo $pmod already installed.
#         fi
#     done
# }

function checkmods()
{
    echo "checking for uninstalled modules..."
    for pmod in $CPANS; do
        perl -e "use ${pmod};" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo -e "MISSING: \t ${pmod}"
        else
            echo -e "found  : \t ${pmod}"
        fi
    done | sort -r
    echo "checking complete."

}




subcommand=$1; shift  

case "$subcommand" in
    # Parse options to the install sub command
install)
    install
    ;;
# mincpan)
#     mincpan
#     ;;
check)
    shift $((OPTIND -1))
    checkmods
    
    ;;
*)
    echo "invalid command: \"$subcommand\""
    echo "expecting: \"install\" or \"check\" "
    ;;
esac







