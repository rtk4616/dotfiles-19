### bashrc.virtualenvwrapper.sh

# sudo apt-get install virtualenvwrapper || sudo pip install virtualenvwrapper
#
export __WRK=${__WRK:-"${HOME}/-wrk"}
export PROJECT_HOME="${__WRK}"
export WORKON_HOME="${__WRK}/-ve27"

_setup_virtualenvwrapper () {
    # _setup_virtualenvwrapper()    -- configure $VIRTUALENVWRAPPER_*
    #export VIRTUALENVWRAPPER_SCRIPT="/usr/local/bin/virtualenvwrapper.sh"
    #export VIRTUALENVWRAPPER_SCRIPT="${HOME}/.local/bin/virtualenvwrapper.sh"
    export VIRTUALENVWRAPPER_SCRIPT=$(which virtualenvwrapper.sh)
    export VIRTUALENVWRAPPER_HOOK_DIR="${__DOTFILES}/etc/virtualenvwrapper"
    export VIRTUALENVWRAPPER_LOG_DIR="${PROJECT_HOME}/.virtualenvlogs"
    if [ -n "${__IS_MAC}" ]; then
        export VIRTUALENVWRAPPER_PYTHON="/usr/local/bin/python"
    else
        export VIRTUALENVWRAPPER_PYTHON=$(which python)
    fi
    unset VIRTUALENV_DISTRIBUTE
    source "${VIRTUALENVWRAPPER_SCRIPT}"
}
_setup_virtualenvwrapper

lsvirtualenvs() {
    # lsvirtualenvs()       -- list virtualenvs in $WORKON_HOME
    cmd=${@:-""}
    (cd ${WORKON_HOME} &&
    for venv in $(ls -adtr ${WORKON_HOME}/**/lib/python?.? | \
        sed "s:$WORKON_HOME/\(.*\)/lib/python[0-9]\.[0-9]:\1:g"); do
        if [ -n "${cmd}" ]; then
            $cmd $venv ;
        else
            echo "${venv}" ;
        fi
    done)
}
lsve() {
    # lsve()                -- list virtualenvs in $WORKON_HOME
    lsvirtualenvs $@
}

backup_virtualenv() {
    # backup_virtualenv()   -- backup VIRTUAL_ENV_NAME $1 to [$2]
    venv=${1}
    _date=$(date +'%FT%T%z')
    bkpdir=${2:-"${WORKON_HOME}/_venvbkps/${_date}"}
    test -d ${bkpdir} || mkdir -p ${bkpdir}
    archivename="venvbkp.${venv}.${_date}.tar.gz"
    archivepath="${bkpdir}/${archivename}"
    (cd ${WORKON_HOME}; \
    tar czf ${archivepath} ${venv} \
        && echo "${archivename}" \
        || (echo "err: ${venv} (${archivename})" 1>&2))
}

backup_virtualenvs() {
    # backup_virtualenvs()  -- backup all virtualenvs in $WORKON_HOME to [$1]
    date=$(date +'%FT%T%z')
    bkpdir=${1:-"${WORKON_HOME}/_venvbkps/${date}"}
    echo BKPDIR="${bkpdir}"
    test -d ${bkpdir} || mkdir -p ${bkpdir}
    lsvirtualenvs
    venvs=$(lsvirtualenvs)
    (cd ${WORKON_HOME}; \
    for venv in ${venvs}; do
        backup_virtualenv ${venv} ${bkpdir} \
        2>> ${bkpdir}/venvbkps.err \
        | tee -a ${bkpdir}/venvbkps.list
    done)
    cat ${bkpdir}/venvbkps.err
    echo BKPDIR="${bkpdir}"
}

_rebuild_virtualenv() {
    # rebuild_virtualenv()      -- rebuild a virtualenv, leaving pkgs in place
    #    $1="$VENVSTR"
    #    $2="$VIRTUAL_ENV"
    echo "rebuild_virtualenv()"
    VENVSTR="${1}"
    VIRTUAL_ENV=${2:-"${WORKON_HOME}/${VENVSTR}"}
    _BIN="${VIRTUAL_ENV}/bin"
    #rm -fv ${_BIN}/python ${_BIN}/python2 ${_BIN}/python2.7 \
        #${_BIN}/pip ${_BIN}/pip-2.7 \
        #${_BIN}/easy_install ${_BIN}/easy_install-2.7 \
        #${_BIN}/activate*
    pyver=$(python -c "import sys; print('{}.{}'.format(*sys.version_info[:2]))")
    _PYSITE="${VIRTUAL_ENV}/lib/python${pyver}/site-packages"
    find -E "${_PYSITE}" -iname 'activate*' -delete
    find -E "${_PYSITE}" -iname 'pip*' -delete
    find -E "${_PYSITE}" -iname 'setuptools*' -delete
    find -E "${_PYSITE}" -iname 'distribute*' -delete
    find -E "${_PYSITE}" -iname 'easy_install*' -delete
    find -E "${_PYSITE}" -iname 'python*' -delete
    declare -f 'deactivate' 2>&1 /dev/null && deactivate
    mkvirtualenv ${VENVSTR}
    workon ${VENVSTR}
    we ${VENVSTR}
    _BIN="${VIRTUAL_ENV}/bin"

    if [ "${_BIN}" == "/bin" ]; then
        echo "err: _BIN='${_BIN}'"
        return 1
    fi

    find ${_BIN} -type f | grep -v '.bak$' | grep -v 'python*$' \
        | xargs head -n1
    find ${_BIN} -type f | grep -v '.bak$' | grep -v 'python*$' \
        | xargs  sed -i.bak -E 's,^#!.*python.*,#!'${_BIN}'/python,'
    find $_BIN -name '*.bak' -delete

    find ${_BIN} -type f | grep -v '.bak$' | grep -v 'python*$' \
        | xargs head -n1
    echo "
    # TODO: adjust paths beyond the shebang
    #${_BIN}/pip install -v -v -r <(${_BIN}/pip freeze)
    #${_BIN}/pip install -r ${_WRD}/requirements.txt
    "
}

rebuild_virtualenv() {
    #  rebuild_virtualenv()     -- rebuild a virtualenv
    #    $1="$VENVSTR"
    #    $2="$VIRTUAL_ENV"
    (set -x; _rebuild_virtualenv $@)
}

rebuild_virtualenvs() {
    # rebuild_virtualenvs()     -- rebuild all virtualenvs in $WORKON_HOME
    lsve rebuild_virtualenv
}
