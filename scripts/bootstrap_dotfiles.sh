#!/bin/bash

## westurner/dotfiles bootstrap_dotfiles.sh

# Install and upgrade dotfiles for the current user
#
# Can be run:
# * in a virtualenv (as current user)
# * for --user (as current user)
#
# * Clones into $VIRTUAL_ENV/src/dotfiles
# * Symlinks $VIRTUAL_ENV/src/dotfiles) to ${HOME}/-dotfiles
# * Symlinks from ~/-dotfiles/<...> into ${HOME}
#
# usage::
#
#    bash scripts/bootstrap_dotfiles.sh -h


# Stop (exit) on error
set -e

# Print commands as they run
#set -v
#set -x


## date (file suffix for backup_and_symlink)
BKUPID=$(date +%Y-%m-%dT%H:%M:%S%z)

## Virtualenvwrapper
WORKON_HOME=${WORKON_HOME:-"${HOME}/-wrk/-ve"}

## Virtualenv + Venv
VIRTUAL_ENV_NAME="dotfiles"
VIRTUAL_ENV="${WORKON_HOME}/${VIRTUAL_ENV_NAME}"
_WRD=${VIRTUAL_ENV}/src/dotfiles
__DOTFILES=${_WRD}

__DOTFILES_SYMLINK="${HOME}/-dotfiles"  # ~/-dotfiles

## dotfiles repository
DOTFILES_REPO_DEST_PATH="${_WRD}"
DOTVIM_REPO_DEST_PATH="${DOTFILES_REPO_DEST_PATH}/etc/vim"

DOTFILES_GIT_REPO_URL="https://github.com/westurner/${VIRTUAL_ENV_NAME}"
#DOTFILES_HG_REPO_URL="https://bitbucket.org/westurner/dotfiles"

DOTVIM_GIT_REPO_URL="https://github.com/westurner/dotvim"
# DOTVIM_HG_REPO_URL="https://bitbucket.org/westurner/dotvim"

#PIP="${HOME}/.local/bin/pip"
PIP="pip"
PIP_INSTALL="${PIP} install"
PIP_INSTALL_USER="${PIP} install --user"
SETUP_PY_OPTS=""
SETUP_PY_OPTS_USER="--user"

if [ -n "$WORKON_HOME" ] && [[ ! -d "$WORKON_HOME" ]]; then
    mkdir -p $WORKON_HOME
fi

_dotfiles_check_deps() {
    # dotfiles_check_deps   -- check for installed packages
    type bash
    type python
    type pip
    type virtualenv
    type virtualenvwrapper.sh
    python -c "import setuptools, pkg_resources; print(pkg_resources.resource_filename('setuptools', ''))"
    type git
    type git-flow
    type git-hf
    type hg
    type venv.py
    type venv
    type dotfiles
    # && dotfiles --help
    echo "__DOTFILES='${__DOTFILES}'"
    echo "__WRK='${__WRK}'"
    echo "WORKON_HOME='${WORKON_HOME}'"
}

dotfiles_check_deps() {
    #see: _dotfiles_check_deps
    (set -x +e; _dotfiles_check_deps)
}

git_status() {
    # git_status()      -- show git rev, branches, remotes
    (git branch -v && \
    git remote -v &&
    git status)
}

hg_status() {
    # hg_status()       -- show hg id, branches, paths
    pwd && \
    hg log \
        --pager never \
        -r $(hg id -i | cut -f1 -d'+') \
        --template '{date|isodate} {date|age} {node|short} {branch} {tags} {bookmarks} {desc|firstline} [{author|user}]\n' && \
    hg id && \
    hg branch -v && \
    hg paths
}

show_status() {
    # show_status()     -- show status for a (.hg or .git) repository
    dir=${1:-$(pwd)}
    if [[ -d "${dir}/.hg" ]]; then
        hg_status
    elif [[ -d "${dir}/.git" ]]; then
        git_status
    else
        echo ".hg or .git repository not found in ${dir}"
    fi
}

clone_or_update() {
    # clone_or_update() -- clone OR pull and update (git [or hg])
    url=$1
    rev=${2:-"master"}  # tip, master
    dest=$3
    echo ""
    if [[ -d "${dest}/.git" ]]; then
        echo "## pulling from ${url} ---> ${dest}"
        (cd $dest && echo "cd $(pwd)" && \
            git_status && \
            git pull "$url" && \
            git checkout "$rev" && \
            git_status);
    elif [[ -d "${dest}/.hg" ]]; then
        default_path=$(cd $dest && hg paths | grep default) 
        echo "## pulling from ${default_path} ---> ${dest}"
        (cd $dest && echo "cd $(pwd)" && \
            hg_status && \
            hg pull && \
            hg update -r "$rev" && \
            hg_status);
    else
        echo "## cloning from ${url} ---> ${dest}"
        (git clone ${url} ${dest} && \
            cd $dest && echo "cd $(pwd)" && \
            git checkout "$rev" && \
            git_status)
    fi
}


clone_dotfiles_repo() {
    # clone_dotfiles_repo()         -- clone/up dotfiles_repo; create symlinks
    url=${DOTFILES_GIT_REPO_URL}
    rev=${DOTFILES_REPO_REV:-"master"}  # tip, master
    dest=${DOTFILES_REPO_DEST_PATH}
    clone_or_update "${url}" "${rev}" "${dest}"

    # Create a $__DOTFILES symlink
    symlink_home_dotfiles
}


clone_dotvim_repo(){
    # clone_dotvim_repo()           -- clone dotvim to etc/vim
    local url=${DOTVIM_GIT_REPO_URL}
    local rev=${DOTVIM_REPO_REV:-"master"}  # tip, master
    local dest=${DOTVIM_REPO_DEST_PATH}
    clone_or_update "${url}" "${rev}" "${dest}"
}

install_virtualenvwrapper() {
    # install_virtualenvwrapper()   -- pip install virtualenvwrapper
    pip install virtualenvwrapper
    #   OR: (manually) apt-get install python-virtualenvwrapper
}

install_gitflow() {
    # install_gitflow()     -- install gitflow git workflow [git flow help]
    local url="https://github.com/nvie/gitflow"
    local rev="master"
    local dest="${__DOTFILES}/src/gitflow"

    clone_or_update "${url}" "${rev}" "${dest}"

    INSTALL_PREFIX="${HOME}/.local/bin" bash ${dest}/contrib/gitflow-installer.sh
}

install_hubflow() {
    # install_hubflow()     --  Install hubflow git workflow [git hf help]
    local url="https://github.com/datasift/hubflow"
    local rev="master"
    local dest="${__DOTFILES}/src/hubflow"

    clone_or_update "${url}" "${rev}" "${dest}"

    INSTALL_PREFIX="${HOME}/.local/bin" bash ${dest}/install.sh
}

get_md5sums() {
    # get_md5sums()     -- get md5sums for a path or directory
    local path=${1}

    if [ -x "/sbin/md5" ]; then
        MD5FUNC="md5"
    else
        MD5FUNC="md5sum"
    fi
    # TODO XXX FIXME: find symlinks

    if [[ -d  "$path" ]]; then
        ${MD5FUNC} $(
            find $path -type f \
            | egrep -v '\.git|\.hg/' \
            | cut -f1 -d' ')
    elif [[ -f "$path" ]]; then
        ${MD5FUNC} $path \
            | cut -f1 -d' '
    elif [[ -s "$path" ]]; then
        ${MD5FUNC} $path \
           | cut -f1 -d' '
    fi
}

__realpath() {
    # __realpath()  -- os.path.realpath (~ readlink -f --canonicalize)
    local _path=$1
    python -c "import os,sys;print(os.path.realpath(sys.argv[1]))" "${_path}";
}

backup_and_symlink() {
    # backup_and_symlink()  -- Create symlink at $dest, pointing to $src
    # Args:
    #  filename: basename of file
    #  dest: location of symlink
    #  src: where symlink will point
    #  BKUPID: file suffix ( *.bkp.* ) (date)
    local filename=${1}
    local dest=${2:-"${HOME}/${filename}"}
    local src=${3:-"${__DOTFILES}/etc/${filename}"}
    local bkp=${dest}.bkp.${BKUPID}
    local dest_md5=''
    local src_md5=''
    #echo "# $filename $dest $src"
    if (test -a ${dest} || test -h ${dest}); then
        if [[ -s ${dest} ]]; then
            dest_md5=$(__realpath $dest)
            src_md5=$(__realpath $src)
        else
            dest_md5=$(get_md5sums $dest)
            src_md5=$(get_md5sums $src)
        fi
        if [ -z "$src_md5" ] && [ -z "$dest_md5" ]; then
            echo "#  $filename $dest $src"
            echo "#! empy md5s"
        fi
        if [ "$src_md5" != "$dest_md5" ]; then
            echo $dest
            echo $dest_md5
            echo $src
            echo $src_md5

            #diff -Naur $src $dest | tee dotfiles.backup.${BKUPID}.diff

            mv ${dest} ${bkp}
            echo "mv ${dest} ${bkp}"
            ln -s ${src} ${dest}
            echo "ln -s ${src} ${dest}"
        else
            # if either src_md5 or dest_md5 are null
            if [ -z "$src_md5" ] || [ -z "$dest_md5" ]; then
                echo "# $src $dest"
                if [ -h ${dest} ]; then
                    local actual=$(__realpath ${dest})
                    if [ "$actual" != "$src" ]; then
                        mv ${dest} ${bkp}
                        echo "mv ${dest} ${bkp}"
                        ln -s ${src} ${dest}
                        echo "ln -s ${src} ${dest}"
                    fi
                else
                    #echo "skip: " $src "->" $dest
                    true
                fi
            else
                echo "## ln -s '${src}' '${dest}'"
                #echo "... $src_md5 == $dest_md5"
            fi
        fi
    else
        ln -s ${src} ${dest}
        echo "ln -s ${src} ${dest}"
    fi

}

## /begin symlinks

symlink_home_dotfiles() {
    backup_and_symlink "" ${__DOTFILES_SYMLINK} ${_WRD}
}

symlink_etc_vim() {
    backup_and_symlink vim/vimrc ${HOME}/.vimrc
    backup_and_symlink vim/ ${HOME}/.vim
}

symlink_bashrc() {
    backup_and_symlink .bashrc
}

symlink_zshrc() {
    backup_and_symlink .zshrc
}

symlink_hgrc() {
    backup_and_symlink .hgrc
    backup_and_symlink .hgrc
    #TODO: set name in ~/.hgrc
}

symlink_gitconfig() {
    backup_and_symlink .gitconfig
    backup_and_symlink .gitignore_global
    #TODO: set name in ~/.gitconfig
}

symlink_inputrc() {
    backup_and_symlink .inputrc
}

symlink_htoprc() {
    backup_and_symlink .htoprc
}

symlink_mutt() {
    backup_and_symlink mutt "${HOME}/.mutt"
}

symlink_gtk() {
    backup_and_symlink .gtkrc
    backup_and_symlink .gtkrc-2.0
    mkdir -p "${HOME}/.config/"
    backup_and_symlink .config/gtk-3.0
}

symlink_mimeapps() {
    mkdir -p ${HOME}/.local/share/applications
    backup_and_symlink mimeapps.list \
        "${HOME}/.local/share/applications/mimeapps.list"
}

symlink_i3() {
    backup_and_symlink i3 "${HOME}/.i3"
}

symlink_xinitrc_screensaver() {
    backup_and_symlink .xinitrc
}

symlink_xmodmap() {
    backup_and_symlink .Xmodmap
}

symlink_python() {
    backup_and_symlink .pythonrc
    backup_and_symlink .pydistutils.cfg
    mkdir -p "${HOME}/.pip"
    backup_and_symlink .pip/pip.conf
    # TODO: .config/pip/.conf
    backup_and_symlink .pdbrc
    backup_and_symlink .noserc
}

symlink_virtualenvwrapper() {
    backup_and_symlink virtualenvwrapper
}

symlink_venv() {
    #backup_and_symlink .ipython/profile_default
    #backup_and_symlink .ipython/profile_default/ipython_config.py
    mkdir -p "${HOME}/.ipython/profile_default/"
    backup_and_symlink ipython/ipython_config.py \
        "${HOME}/.ipython/profile_default/ipython_config.py"
}


symlink_ruby() {
    backup_and_symlink .gemrc
}

## end /symlinks

dotfiles_symlink_all() {
    ## Create symlinks
    symlink_home_dotfiles

    symlink_inputrc
    symlink_bashrc
    symlink_zshrc
    symlink_htoprc
    symlink_etc_vim

    symlink_python
    symlink_virtualenvwrapper
    symlink_venv

    symlink_ruby

    symlink_gtk
    symlink_i3
    symlink_xinitrc_screensaver
    symlink_xmodmap

    # {{ full_name }}
    symlink_gitconfig
    symlink_hgrc
    symlink_mutt

}

create_virtualenv() {
    ## create a new virtualenv 
    _virtual_env=$_VIRTUAL_ENV
    VENVWRAPPER=$(which virtualenvwrapper.sh)

    if [[ -x "${VENVWRAPPER}" ]]; then
        dotfiles_setup_virtualenvwrapper
        source $VENVWRAPPER

        mkvirtualenv ${VIRTUAL_ENV_NAME}
        workon ${VIRTUAL_ENV_NAME}
    elif [[ -f "${_virtual_env}/bin/activate" ]]; then
        # Create a new virtualenv
        source ${_virtual_env}/bin/activate
    fi
}

deactivate_virtualenv() {
    ## deactivate any current VIRTUAL_ENV in this $SHELL
    type 'virtualenv_deactivate' 2>/dev/null && virtualenv_deactivate || true
    type 'virtualenv_deactivate' 2>/dev/null && virtualenv_deactivate || true
    unset VIRTUAL_ENV
}

dotfiles_install_bootstrap() {
    ## pip install --upgrade --editable and create symlinks

    if [ -z "$SETUP_PY_OPTS" ]; then
        source "${_VIRTUAL_ENV}/bin/activate"
    else
        deactivate_virtualenv
    fi
    ${PIP_INSTALL} --upgrade --editable ${DOTFILES_REPO_DEST_PATH}
    cd ${DOTFILES_REPO_DEST_PATH} && \
        dotfiles_symlink_all
}

dotfiles_install_bootstrap_user() {
    ## pip install --user --editable and create symlinks

    #TODO: subshell
    deactivate_virtualenv
    ${PIP_INSTALL_USER} --upgrade --editable ${DOTFILES_REPO_DEST_PATH}
    cd ${DOTFILES_REPO_DEST_PATH} && \
        dotfiles_symlink_all
}

dotfiles_install_boostrap_env() {
    ## Setup system dependencies

    # Upgrade system pip
    #pip_bootstrap_pip
    ###pip_upgrade_local_pip
    #pip_upgrade_system_pip
    #pip_upgrade_system_setuptools

    deactivate_virtualenv

    # Install virtualenv and virtualenvwrapper into ~/.local/bin/
    pip_install_virtualenv
    pip_install_virtualenvwrapper

    dotfiles_setup_virtualenvwrapper

}

dotfiles_upgrade() {
    ## clone and/or pull and update dotfiles and dotvim; then install dotfiles

    # Clone the dotfiles repository
    clone_dotfiles_repo

    # Clone the dotvim repository
    clone_dotvim_repo

    # Install dotfiles into ${HOME}
    dotfiles_install_bootstrap

    # Install dotfiles into ~/.local/
    #(dotfiles_install_bootstrap_user)

}

dotfiles_install() {
    ## Install the dotfiles

    # install and configure virtualenv and virtualenvwrapper
    dotfiles_install_boostrap_env

    if [ -r "$SETUP_PY_OPTS" ]; then
        # create or activate $_VIRTUAL_ENV
        create_virtualenv #  ${VIRTUAL_ENV_NAME}
    fi

    ## Clone and/or pull and update dotfiles and dotvim; then install dotfiles
    dotfiles_upgrade

    # Symlink dotfiles into ${HOME}
    dotfiles_symlink_all
}

dotfiles_install_requirements() {
    ## Install all pip requirements
    ${PIP_INSTALL} -r "${DOTFILES_REPO_DEST_PATH}/requirements-all.txt"
}


pip_upgrade_system_setuptools() {
    ## Upgrade setuptools with pip
    sudo pip install --upgrade setuptools
}

pip_upgrade_system_pip() {
    ## Upgrade system pip with pip (careful)
    sudo pip install --upgrade pip
}

pip_upgrade_local_pip() {
    ## Upgrade pip with pip (does not work)
    ${PIP_INSTALL_USER} --force-reinstall --upgrade pip  # seems to error out
}

pip_bootstrap_pip() {
    ## Install pip (and setuptools)
    wget --continue "https://bootstrap.pypa.io/get-pip.py"
    python get-pip.py $SETUP_PY_OPTS
}

bootstrap_setuptools() {
    ## Install setuptools
    wget --continue "https://bootstrap.pypa.io/ez_setup.py"
    python ez_setup.py $SETUP_PY_OPTS
}


pip_install_virtualenv() {
    ## Install virtualenv
    ${PIP_INSTALL} --upgrade --no-use-wheel virtualenv
}

pip_install_virtualenvwrapper() {
    ## Install virtualenvwrapper
    ${PIP_INSTALL} --upgrade --no-use-wheel virtualenvwrapper
}


dotfiles_setup_virtualenvwrapper() {
    ## source virtualenvwrapper[_lazy].sh from $PATH

    VIRTUALENVWRAPPER_SH_NAME="virtualenvwrapper.sh"
    #VIRTUALENVWRAPPER_SH_NAME="virtualenvwrapper_lazy.sh

    VIRTUALENVWRAPPER_SH=$(which ${VIRTUALENVWRAPPER_SH_NAME})
    #VIRTUALENVWRAPPER_SH="${HOME}/.local/bin/${VIRTUALENVWRAPPER_SH_NAME}"

    if [[ -f ${VIRTUALENVWRAPPER_SH} ]]; then
        source ${VIRTUALENVWRAPPER_SH}
    else
        echo "404: VIRTUALENVWRAPPER_SH=${VIRTUALENVWRAPPER_SH}"
    fi
    # TODO: check .bashrc.venv.sh for .local/bin path lookup
}


dotfiles_bootstrap_usage() {
    ## print usage information
    echo "## dotfiles_bootstrap -- a shell wrapper for cloning and installing"

    echo "## Usage: $(basename ${0}) <actions> <options>";
    echo "#"
    echo "## Actions"
    echo "#  -I   --  Install the dotfiles";
    echo "#  -S   --  Install dotfiles symlinks";
    echo "#  -U   --  Update and Upgrade the dotfiles";
    echo "#  -R   --  pip install -r requirements-all.txt"
    echo "#  -G   --  install Gitflow and hubflow"
    echo "#  -C   --  check for installed components"
    echo "#  -h   --  print this help message"
    echo "#"
    echo "## Options"
    echo "#  -u   --  pip install --user (modified for other actions)"
    echo "#  -d   --  show debugging info (set -x)"
    exit;
}


dotfiles_bootstrap_main () {
    ## parse opts, set flags, and run commands
    while getopts "uISURGCdh" o; do
        case "${o}" in
            u)
                u=${OPTARG};
                export PIP_INSTALL="${PIP_INSTALL_USER}"
                export SETUP_PY_OPTS="${SETUP_PY_OPTS_USER}"
                ;;
            I)
                I=${OPTARG};
                DO_INSTALL="true"
                ;;
            S)
                S=${OPTARG};
                DO_SYMLINK="true"
                ;;
            U)
                U=${OPTARG};
                DO_UPGRADE="true"
                DO_SYMLINK="true"
                ;;
            R)
                R=${OPTARG};
                DO_PIP_REQUIREMENTS="true"
                ;;
            G)
                G=${OPTARG};
                DO_GIT_REQUIREMENTS="true"
                ;;
            C)
                C=${OPTARG};
                DO_CHECK="true"
                ;;
            d)
                d=${OPTARG};
                DEBUG_BOOTSTRAP="true"
                ;;
            h|*)
                dotfiles_bootstrap_usage;
                exit
                ;;
        esac
    done

    if [ -n "$DEBUG_BOOTSTRAP" ]; then
        set -x
        set -v
    fi

    if [ -n "$DO_CHECK" ]; then
        dotfiles_check_deps;
    fi
    if [ -n "$DO_INSTALL" ]; then
        dotfiles_install;
    fi
    if [ -n "$DO_UPGRADE" ]; then
        dotfiles_upgrade;
    fi
    if [ -n "$DO_SYMLINK" ]; then
        dotfiles_symlink_all;
    fi
    if [ -n "$DO_PIP_REQUIREMENTS" ]; then
        dotfiles_install_requirements
    fi
    if [ -n "$DO_GIT_REQUIREMENTS" ]; then
        install_gitflow;
        install_hubflow;
    fi
    if [ -n "$DO_CHECK" ]; then
        dotfiles_check_deps
    fi

}

## execute main if called as a script
## (e.g. not with `source`)
if [[ "$BASH_SOURCE" == $0 ]]; then
    dotfiles_bootstrap_main $@
fi

