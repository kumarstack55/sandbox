#!/bin/bash

set -eu

gloval_variables() {
  FNAME_CPIO_IT=cpio_it.txt
  FNAME_LICENSE=license.txt
  FNAME_TEMPLATE_DEST_LIST=template_dest_list.txt
  FNAME_UNIT_LIST=unit_list.txt
  MSG_SKIP_DRYRUN="skip. (dry-run)"
  MSG_SKIP_FILE_EXISTS="skip. (file already exists)"

  option_dry_run=no
  option_force_overwrite=no
  option_leave_tmp_dir=no
  option_galaxy_tag=""

  env_author_info=""
  env_github_username=""
}

read_vars_from_env() {
  local rc_dir="$HOME/.config/generate-ansible-role-skel"
  mkdir -pv $rc_dir

  local rc_file="$rc_dir/config.sh"
  if [[ ! -f $rc_file ]]; then
    echo "# Generating: $rc_file"
    cat <<__BASH__ | tee $rc_file >/dev/null
#AUTHOR_INFO="xxx"
#GITHUB_USERNAME="xxx"
__BASH__
  fi
  source $rc_file

  # TODO: hard coding
  if [[ ! -v AUTHOR_INFO ]]; then
    die "Please define AUTHOR_INFO in $rc_file"
  fi
  env_author_info="$AUTHOR_INFO"

  # TODO: hard coding
  if [[ ! -v GITHUB_USERNAME ]]; then
    die "Please define GITHUB_USERNAME in $rc_file"
  fi
  env_github_username="$GITHUB_USERNAME"
}

usage_exit() {
  prog="./$(basename $0)"
  echo_err "usage: $prog [OPTIONS...] RPM_PKG_NAME"
  echo_err ""
  echo_err "options:"
  echo_err " --dry-run       : Don't make any change"
  echo_err " -f, --force     : Force overwrite"
  echo_err " --leave-tmp-dir : Don't remove temporary directory"
  exit 1
}

echo_err() {
  echo "$1" 1>&2
}

getopt_err_needarg() {
  local optarg="$1"
  echo_err "$0: option requires an argument -- $optarg"
}

getopt_err_badopt() {
  local optarg="$1"
  echo_err "$0: illegal option -- $optarg"
}

die() {
  local msg
  local at="${BASH_SOURCE[1]}:${FUNCNAME[1]}"
  local line="${BASH_LINENO[0]}"

  if [[ $# -gt 0 ]]; then
    msg="$1"; shift;
  fi
  echo_err "${msg:-Died} at $at line $line."
  exit 1
}

generate_readme() {
  local tmp_dir="$1"; shift
  local role_name="$1"; shift
  local init="$1"; shift
  local rpm_pkg_name="$1"; shift

  local license_type=$(cat $tmp_dir/output/$FNAME_LICENSE)

  local ofile=$role_name/README.md
  echo "# Generating: $ofile."
  if [[ $option_dry_run == yes ]]; then
    echo $MSG_SKIP_DRYRUN
    echo
    return
  fi

  if [[
    $init != yes && -f $ofile &&
    $option_force_overwrite != yes
  ]]; then
    echo $MSG_SKIP_FILE_EXISTS
    echo
    return
  fi

  : >$ofile

  cat <<__README_MD__ | tee -a $ofile >/dev/null
ansible-role-${rpm_pkg_name}
=============$(echo $rpm_pkg_name | sed -e 's/./=/g')

A ansible role to install and/or configure ${rpm_pkg_name}.

Requirements
------------

* EL7

Role Variables
--------------

None.

Dependencies
------------

None.

Example Playbook
----------------

\`\`\`yaml
- hosts: servers
  roles:
    - role: ${env_github_username}.${rpm_pkg_name}
\`\`\`

License
-------

$license_type

Author Information
------------------

$env_author_info
__README_MD__

  echo
}

generate_meta() {
  local tmp_dir="$1"; shift
  local role_name="$1"; shift
  local init="$1"; shift
  local rpm_pkg_name="$1"; shift

  local ofile=$role_name/meta/main.yml
  echo "# Generating: $ofile."
  if [[ $option_dry_run == yes ]]; then
    echo $MSG_SKIP_DRYRUN
    echo
    return
  fi

  if [[
    $init != yes && -f $ofile &&
    $option_force_overwrite != yes
  ]]; then
    echo $MSG_SKIP_FILE_EXISTS
    echo
    return
  fi

  : >$ofile

  local license_type=$(cat $tmp_dir/output/$FNAME_LICENSE)

  local galaxy_tag="$option_galaxy_tag"
  if [[ $galaxy_tag == "" ]]; then
    galaxy_tag="$rpm_pkg_name"
  fi

  if [[ $galaxy_tag =~ _|- ]]; then
    tag=$(echo $rpm_pkg_name | sed -e 's/-.*//')
    echo_err "galaxy_tags can't contains '_' or '-'"
    echo_err "galaxy_tag: $galaxy_tag"
    echo_err "use option to set tag like:"
    echo_err "  --galaxy-tag $tag"
    die
  fi

  cat <<__YAML__ | tee -a $ofile >/dev/null
galaxy_info:
  author: $env_github_username
  description: $rpm_pkg_name
  license: $license_type
  min_ansible_version: 1.2
  platforms:
    - name: EL
      versions:
        - 7
  galaxy_tags: [ $galaxy_tag ]
dependencies: []
__YAML__

  echo
}

generate_tasks() {
  local tmp_dir="$1"; shift
  local role_name="$1"; shift
  local init="$1"; shift
  local rpm_pkg_name="$1"; shift

  local ofile=$role_name/tasks/main.yml
  echo "# Generating: $ofile."
  if [[ $option_dry_run == yes ]]; then
    echo $MSG_SKIP_DRYRUN
    echo
    return
  fi

  if [[
    $init != yes && -f $ofile &&
    $option_force_overwrite != yes
  ]]; then
    echo $MSG_SKIP_FILE_EXISTS
    echo
    return
  fi

  : >$ofile

  cat <<__YAML__ | tee -a $ofile >/dev/null
---
- name: Ensure package installed
  yum:
    name: ${rpm_pkg_name}

- name: Ensure configure files exists
  template:
    dest: "{{ item.dest }}"
    src: "{{
        item.src
        | default(
            item.dest
            | regex_replace('/\\\\.', '/dot.')
            | regex_replace('^/', 'el7/')
          ) + '.j2'
      }}"
    force: yes
    backup: yes
  loop:
__YAML__

  cat $tmp_dir/output/$FNAME_TEMPLATE_DEST_LIST \
  | while read -r dest; do
      cat <<__YAML__ | tee -a $ofile >/dev/null
    - dest: $dest
__YAML__
    done

  cat <<__YAML__ | tee -a $ofile >/dev/null
#  notify:
__YAML__

  cat $tmp_dir/output/$FNAME_UNIT_LIST \
  | while read -r unit; do
      cat <<__YAML__ | tee -a $ofile >/dev/null
#    - Ensure ${unit} service restarted
__YAML__
    done

  cat <<__YAML__ | tee -a $ofile >/dev/null
#
#- name: Ensure service enabled
#  systemd:
#    name: "{{ item }}"
#    enabled: yes
#  loop:
__YAML__

  cat $tmp_dir/output/$FNAME_UNIT_LIST \
  | while read -r unit; do
      cat <<__YAML__ | tee -a $ofile >/dev/null
#    - ${unit}.service
__YAML__
    done

  cat <<__YAML__ | tee -a $ofile >/dev/null
#  notify:
__YAML__

  cat $tmp_dir/output/$FNAME_UNIT_LIST \
  | while read -r unit; do
      cat <<__YAML__ | tee -a $ofile >/dev/null
#    - Ensure ${unit} service restarted
__YAML__
    done

  echo
}

generate_templates() {
  local tmp_dir="$1"; shift
  local role_name="$1"; shift
  local init="$1"; shift
  local rpm_pkg_name="$1"; shift

  cat $tmp_dir/output/$FNAME_TEMPLATE_DEST_LIST \
  | while read -r line; do
      local tmpl_dest="$line"
      local tmpl_src="$role_name/templates/el7${line}.j2"
      local tmpl_src_dir=$(dirname $tmpl_src)

      echo "# Generating: $tmpl_src"
      if [[ $option_dry_run == yes ]]; then
        echo $MSG_SKIP_DRYRUN
        echo
        return
      fi
      if [[ -f $tmpl_src && $option_force_overwrite != yes ]]; then
        echo $MSG_SKIP_FILE_EXISTS
        echo
        return
      fi

      mkdir -pv $tmpl_src_dir
      rpm2cpio $pkg_path \
        | cpio -i --to-stdout .$line \
        | tee $tmpl_src >/dev/null

      echo
    done
}

generate_handlers() {
  local tmp_dir="$1"; shift
  local role_name="$1"; shift
  local init="$1"; shift
  local rpm_pkg_name="$1"; shift

  local ofile=$role_name/handlers/main.yml
  echo "# Generating: $ofile."
  if [[ $option_dry_run == yes ]]; then
    echo $MSG_SKIP_DRYRUN
    echo
    return
  fi

  if [[
    $init != yes && -f $ofile &&
    $option_force_overwrite != yes
  ]]; then
    echo $MSG_SKIP_FILE_EXISTS
    echo
    return
  fi

  : >$ofile

  cat $tmp_dir/output/$FNAME_UNIT_LIST \
    | while read -r unit; do
        cat <<__YAML__ | tee -a $ofile >/dev/null
- name: Ensure ${unit} service restarted
  systemd:
    name: ${unit}.service
    state: restarted

__YAML__
      done

  echo
}

generate_tests() {
  local tmp_dir="$1"; shift
  local role_name="$1"; shift
  local init="$1"; shift
  local rpm_pkg_name="$1"; shift

  local ofile=$role_name/tests/test.yml
  echo "# Generating: $ofile."
  if [[ $option_dry_run == yes ]]; then
    echo $MSG_SKIP_DRYRUN
    echo
    return
  fi

  if [[
    $init != yes && -f $ofile &&
    $option_force_overwrite != yes
  ]]; then
    echo $MSG_SKIP_FILE_EXISTS
    echo
    return
  fi

  : >$ofile

  cat <<__YAML__ | tee -a $ofile >/dev/null
---
- hosts: localhost
  gather_facts: no
  become: yes
  roles:
    - ansible-role-${rpm_pkg_name}
__YAML__

  echo
}

main() {
  local rpm_pkg_name="$1"; shift

  local tmp_dir=$(mktemp -d)
  local rpm_dir="$tmp_dir/rpm"
  local out_dir="$tmp_dir/output"

  echo "# Downloading rpm package..."
  mkdir -p $rpm_dir
  yumdownloader --destdir $rpm_dir $rpm_pkg_name 2>&1 >/dev/null
  local pkg_path=$(readlink -f $(find $rpm_dir -type f))
  echo "rpm file: $pkg_path"
  echo

  echo "# Get license type..."
  rpm -q -p $pkg_path --qf "%{LICENSE}" \
    >$out_dir/$FNAME_LICENSE
  cat "$out_dir/$FNAME_LICENSE"
  echo

  echo "# Listing files from package..."
  mkdir -pv $out_dir
  rpm2cpio $pkg_path \
    | cpio -it \
    | sed -e 's/^\.//' \
    >$out_dir/$FNAME_CPIO_IT
  echo

  echo "# Listing destination path..."
  cat \
    <(grep -P "^(/etc/|/var/lib/)" $out_dir/$FNAME_CPIO_IT) \
    <(rpm -q -p $pkg_path -l | grep -P "^(/etc/|/var/lib/)") \
    | sort \
    | uniq --repeated \
    >$out_dir/$FNAME_TEMPLATE_DEST_LIST
  echo

  echo "# Listing systemd units..."
  set +e
  rpm -q -p $pkg_path -l \
    | grep -Po "(?<=^/usr/lib/systemd/system/).+(?=.service)" \
    >$out_dir/$FNAME_UNIT_LIST
  set -e
  echo

  echo "# Initializing ansible role..."
  local role_name="ansible-role-${rpm_pkg_name}"
  local init=no
  if [[ $option_dry_run == 'yes' ]]; then
    echo $MSG_SKIP_DRYRUN
  elif [[
      ( -e $role_name && $option_force_overwrite == yes ) ||
      ( ! -e $role_name )
    ]]; then
    init=yes
    ansible-galaxy init $role_name
  fi
  echo

  echo "# Generating directory and files..."
  generate_readme    $tmp_dir $role_name $init $rpm_pkg_name
  generate_meta      $tmp_dir $role_name $init $rpm_pkg_name
  generate_tasks     $tmp_dir $role_name $init $rpm_pkg_name
  generate_templates $tmp_dir $role_name $init $rpm_pkg_name
  generate_handlers  $tmp_dir $role_name $init $rpm_pkg_name
  generate_tests     $tmp_dir $role_name $init $rpm_pkg_name

  if [[ $option_leave_tmp_dir == 'yes' ]]; then
    echo "# To remove temporary directory, type:"
    echo "$ rm -rf $tmp_dir"
    echo
  else
    echo "# Removing temporary directory."
    rm -rf $tmp_dir
    echo
  fi
}

gloval_variables
read_vars_from_env

while getopts -- "-:fh" OPT; do
  case $OPT in
    -)
      case $OPTARG in
        dry-run)
          option_dry_run=yes
          ;;
        force)
          option_force_overwrite=yes
          ;;
        leave-tmp-dir)
          option_leave_tmp_dir=yes
          ;;
        galaxy-tag)
          if [[ $OPTIND -gt $BASH_ARGC ]]; then
            echo_err_needarg $OPTARG
            usage_exit
          fi
          LONGOPT_ARG="${BASH_ARGV[$(($BASH_ARGC-$OPTIND))]}"
          option_galaxy_tag=$LONGOPT_ARG
          OPTIND=$((OPTIND+1))
;;

        *)
          getopt_err_badopt $OPTARG
          usage_exit
          ;;
      esac;;
    f) option_force_overwrite=yes;;
    h) usage_exit;;
    \?) usage_exit;;
  esac
done
shift $((OPTIND-1))

if [[ $# -ne 1 ]]; then
  die "no rpm package name"
  usage_exit
fi

main "$*"
exit 0
