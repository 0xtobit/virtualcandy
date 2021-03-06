# VirtualCandy
# Use at your own risk, no quarentee provided.
# Author: Jeff Buttars
# git@github.com:jeffbuttars/virtualcandy.git
# See the README.md

KNRM="\033[0m"
KRED="\033[0;31m"
KGRN="\033[0;32m"
# KYEL="\x1B[33m"
KBLU="\033[0;34m"
# KMAG="\x1B[35m"
# KCYN="\x1B[36m"
# KWHT="\x1B[37m"

pr_pass()
{
    # echo "$1"
    echo -en "${KGRN}$*${KNRM}"
} #make_pass

pr_fail()
{
    echo -en "${KRED}$*${KNRM}"
} #make_fail

pr_info()
{
    echo -en "${KBLU}$*${KNRM}"
} #make_info


# Common code sourced by both bash and zsh
# implimentations of virtualcandy.
# Shell specific code goes into each shells
# primary file.

VC_PROJECT_FILE=".vc_proj"

if [[ -z $VC_DEFUALT_VENV_NAME ]]
then
    VC_DEFUALT_VENV_NAME='.venv'
fi

if [[ -z $VC_DEFUALT_VENV_REQFILE ]]
then
    VC_DEFUALT_VENV_REQFILE='requirements.txt'
fi

if [[ -z $VC_AUTO_ACTIVATION ]]
then
    VC_AUTO_ACTIVATION=true
fi

if [[ -z $VC_PYTHON_EXE ]]
then

    res=$(which python2.7)
    if [[ -n $res ]]; then
        VC_PYTHON_EXE=$(basename $(which python2.7))
    else
        VC_PYTHON_EXE=$(basename $(which python))
    fi
fi

if [[ -z $VC_VIRTUALENV_EXE ]]
then

    VC_VIRTUALENV_EXE=virtualenv

    which virtualenv2 > /dev/null
    res="$?"
    if [[ "$res" == "0" ]]; then
        VC_VIRTUALENV_EXE=$(basename "$(which virtualenv2)")
    fi
fi

if [[ -z $VC_NEW_SHELL ]]
then
    # Highly recommend using 'yes', but the default behavior of
    # virtualenv is not use a new shell, so we mimick it's defaults.
    VC_NEW_SHELL='no'
fi

_vc_source_project_file()
{
    # If a project file exists, source it.
    if [[ -f "$VC_PROJECT_FILE" ]]; then
        if [[ "$SHELL" == "bash" ]]; then
            . ./"$VC_PROJECT_FILE" 
        else
            source ./"$VC_PROJECT_FILE" 
        fi
    fi
} #_vc_source_project_file


function _vcfinddir()
{
    _vc_source_project_file
    cur=$PWD
    vname=$VC_DEFUALT_VENV_NAME
    found='false'

    if [[ -n $1 ]]; then
        vname="$1"
    fi

    while [[ "$cur" != "/" ]]; do
        if [[ -d "$cur/$vname" ]]; then
            found="true"
            echo "$cur"
            break
        fi

        cur=$(dirname $cur)
    done

    if [[ "$cur" == "/" ]]; then
        found="false"
    fi

    if [[ "$found" == "false" ]]; then
        echo ""
    fi
} #_vcfinddir

_vc_ignore()
{
    # Add a git ignore with python friendly defaults.
    local igfile="$(vcfinddir)/.gitignore"

    if [[ ! -f $igfile ]]; then
        echo "$VC_DEFUALT_VENV_NAME" > $igfile
        echo "*.pyo" >> $igfile
        echo "*.pyc" >> $igfile
        git add $igfile
    else
        echo "A .gitignore already exists, doing nothing."
    fi
    
} #_vc_ignore


# Start a new virtualenv, or 
# rebuild on from a requirements.txt file.
function _vcstart()
{

    _vc_source_project_file

    if [[ "$VC_NEW_SHELL" != 'no' ]]; then
        # get our current shell
        C_SHELL="$SHELL"

        # Enter the new shell and start up the env.
        $C_SHELL -c "$THIS_DIR/vc_new_shell.sh"
    fi

    vname=$VC_DEFUALT_VENV_NAME
    if [[ -n $1 ]]; then
        if [[ "$1" != "-" ]]; then
            vname="$1"
        fi
        shift
    fi

    pr_info "$VC_VIRTUALENV_EXE --python=$VC_PYTHON_EXE $@ $vname\n"
    $VC_VIRTUALENV_EXE --python=$VC_PYTHON_EXE $@ $vname
    . $vname/bin/activate

    if [[ -f requirements.txt ]]; then
        pip install -r $VC_DEFUALT_VENV_REQFILE
    fi

    # for pkg in $@ ; do
    #     pip install $pkg
    # done

    if [[ ! -f requirements.txt ]]; then
        vcfreeze
    fi
} #_vcstart

# A simple, and generic, pip update script.
# For a given file containing a pkg lising
# all packages are updated. If no args are given,
# then a 'requirements.txt' file will be looked
# for in the current directory. If the $VC_DEFUALT_VENV_REQFILE
# variable is set, than that filename will be looked
# for in the current directory.
# If an argument is passed to the function, then
# that file and path will be used.
# This function is used by the vcpkgup function
function _pip_update()
{
    _vc_source_project_file
    reqf="requirements.txt"

    if [[ -n $VC_DEFUALT_VENV_REQFILE ]]; then
        reqf="$VC_DEFUALT_VENV_REQFILE"
    fi

    if [[ -n $1 ]]; then
        reqf="$1"
    fi

    res=0
    if [[ -f $reqf ]]; then
        tfile="/tmp/pkglist_$RANDOM.txt"
        pr_info "$tfile\n"
        cat $reqf | awk -F '==' '{print $1}' > $tfile
        pip install --upgrade -r $tfile
        res=$?
        rm -f $tfile
    else
        pr_fail "Unable to find package list file: $reqf\n"
        res=1
    fi

    echo $res
} #_pip_update

# Upgrade the nearest virtualenv packages
# and re-freeze them
function _vcpkgup()
{
    _vc_source_project_file
    local vname=$VC_DEFUALT_VENV_NAME

    vdir=$(vcfinddir $vname)

    reqlist="$vdir/$VC_DEFUALT_VENV_REQFILE"

    if [ ! -z $1 ]; then
        pr_info "Updating $@\n"
        for pkg in "$@" ; do
            pip install -U --no-deps $pkg
            res=$?
        done
        vcfreeze $vname
    elif [[ -f $reqlist ]]; then
        pr_info "Updating all in $reqlist\n"
        vcactivate $vname
        pip_update $reqlist
        res=$?
        if [[ "$res" == 0 || "$res" == "" ]]; then
            vcfreeze $vname
        else
            pr_fail "Bad exit status from pip_update, not freezing the package list.\n"
        fi
    else
        pr_fail "No requirements.txt file found!\n"
        res=0
    fi
    
    return $res
} #_vcpkgup

function _vcfindenv()
{
    _vc_source_project_file
    cur=$PWD
    local vname=$VC_DEFUALT_VENV_NAME

    if [[ -n $1 ]]; then
        vname="$1"
    fi

    vdir=$(vcfinddir $vname)
    res=""
    if [[ -n $vdir ]]; then
        res="$vdir/$vname"
    fi
    echo $res

} #_vcfindenv

function _vcfreeze()
{
    _vc_source_project_file
    vd=''
    if [[ -n $1 ]]; then
        vd=$(vcfinddir $1)
    else
        vd=$(vcfinddir)
    fi

    vcactivate

    mv "$vd/$VC_DEFUALT_VENV_REQFILE"  "$vd/.${VC_DEFUALT_VENV_REQFILE}.bak"
    pip freeze > "$vd/$VC_DEFUALT_VENV_REQFILE"
    cat  "$vd/$VC_DEFUALT_VENV_REQFILE"
} #_vcfreeze

function _vcactivate()
{
    _vc_source_project_file
    
    local vname=$VC_DEFUALT_VENV_NAME
    vloc=''

    if [[ -n $1 ]]; then
        vname="$1"
        shift
    fi

    vloc=$(vcfindenv)

    if [[ -n $vloc ]]; then
        pr_pass "Activating ~${vloc#$HOME/}\n"
        . "$vloc/bin/activate"
    else
        pr_fail "No virtualenv name $vname found.\n"
    fi

} #_vcactivate

function _vctags()
{
    _vc_source_project_file
    vloc=$(vcfindenv)
    filelist="$vloc"

    # ccmd="ctags --sort=yes --tag-relative=no -R --python-kinds=-i"
    ccmd="ctags --tag-relative=no -R --python-kinds=-i"
    pr_info "$ccmd\n"
    if [[ -n $vloc ]]; then
        pr_info "Making tags with $vloc\n"
        filelist="$vloc"
    fi

    if [[ "$#" == "0" ]]; then
        filelist="$filelist *"
    else
        filelist="$filelist $@"
    fi

    ccmd="$ccmd $filelist"
    pr_info "Using command $ccmd\n"
    $ccmd

    res=$(which inotifywait)
    VC_AUTOTAG_RUN=1
    if [[ -n $res ]]; then
        while [[ "$VC_AUTOTAG_RUN" == "1" ]]; do
            inotifywait -e modify -r $filelist
            nice -n 19 ionice -c 3 $ccmd
            # Sleep a bit to keep from hitting the disk
            # to hard during a mad editing burst from 
            # those mad men coders
            sleep 30
        done
    fi
} #_vctags


function _vcbundle()
{
    _vc_source_project_file
    vcactivate
    vdir=$(vcfinddir)
    bname="${VC_DEFUALT_VENV_NAME#.}.pybundle"
    pr_info "Creating bundle $bname\n"
    pip bundle "$bname" -r "$vdir/$VC_DEFUALT_VENV_REQFILE"
} #_vcbundle


function _vcmod()
{
    _vc_source_project_file
    if [[ -z $1 ]]
    then
        pr_fail "$0: At least one module name is required.\n"
        exit 1
    fi 

    for m in $@ ; do
        mkdir -p "$m"
        if [[ ! -f "$m/__init__.py" ]]
        then
            touch "$m/__init__.py" 
        else
            pr_info "$0: A module named $m already exists.\n"
        fi
        pr_pass "created $m/__init__.py\n"
    done
} #_vcmod

_vcin()
{
    _vc_source_project_file
    if [[ -z $1 ]]
    then
        pr_fail "$0: No parameters given. Running install on requirements.txt\n"
        pip install -r "$(_vcfinddir)/requirements.txt"
        vcfreeze
    fi 

    pip install $@
    vcfreeze
} #_vcin

function _vc_auto_activate()
{
    # see if we're under a virtualenv.
    local c_venv="$(vcfindenv)"

    if [[ ! -z $c_venv ]]; then
        # We're in/under an environment.
        # If we're activated, switch to the new one if it's different from the
        # current.
        if [[ ! -z $VIRTUAL_ENV ]]; then
            from="~/${VIRTUAL_ENV#$HOME/}"
            to="~/${c_venv#$HOME/}"
            if [ "$from" != "$to" ]; then
                # Do we need to be this verbose?
                # echo -e "Switching from '$from' to '$to'"
                deactivate
            fi
        fi

        if [[ -z $VIRTUAL_ENV ]]; then
            vcactivate
        fi
    elif [[ ! -z $VIRTUAL_ENV ]]; then
        # We've left an environment, so deactivate.
        pr_info "Deactivating ~/${VIRTUAL_ENV#$HOME/}\n"
        deactivate
    fi
} #_vc_auto_activate


function _vc_reset()
{
    to="$(vcfindenv $@)"
    dto=$(dirname "$to")
    if [[ -d "$to" ]]; then
        rm -fr "$to"
        if [[ "$?" != '0' ]]; then
            exit 1
        fi
        cd $dto
        vcstart
        cd -
    fi

} #_vc_reset
