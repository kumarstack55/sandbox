#!/bin/bash

set -eu

gloval_variables() {
  TEMPLATE_DEST_LIST=template_dest_list.txt
  UNIT_LIST=unit_list.txt

  g_mail=kumarstack55@gmail.com
  g_user=kumarstack55
  option_dry_run=yes
}

usage_exit() {
  prog="./$(basename $0)"
  echo_err "usage: $prog [OPTIONS...] RPM_PKG_NAME"
  echo_err ""
  echo_err "options:"
  echo_err " --dry-run           : Don't make any change (default)"
  echo_err " -f, --force         : Force mode"
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
  local role_name="$1"; shift
  local rpm_pkg_name="$1"; shift

  local ofile=$role_name/README.md
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

no variables.

Dependencies
------------

no dependencies.

Example Playbook
----------------

\`\`\`yaml
- hosts: servers
  roles:
    - role: ${g_user}.${rpm_pkg_name}
\`\`\`

License
-------

GPLv3

Author Information
------------------

$g_mail
__README_MD__
}

generate_meta() {
  local role_name="$1"; shift
  local rpm_pkg_name="$1"; shift

  local ofile=$role_name/meta/main.yml
  : >$ofile

  cat <<__YAML__ | tee -a $ofile >/dev/null
galaxy_info:
  author: $g_user
  description: $rpm_pkg_name
  license: GPL
  min_ansible_version: 1.2
  platforms:
    - name: EL
      versions:
        - 7
  galaxy_tags: [ $rpm_pkg_name ]
dependencies: []
__YAML__
}

generate_tasks() {
  local role_name="$1"; shift
  local rpm_pkg_name="$1"; shift

  local ofile=$role_name/tasks/main.yml
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
            | regex_replace('/\\.', '/dot.')
            | regex_replace('^/', 'el7/')
          ) + '.j2'
      }}"
    force: yes
    backup: yes
  loop:
__YAML__

  cat ./output/$TEMPLATE_DEST_LIST \
  | while read -r dest; do
      cat <<__YAML__ | tee -a $ofile >/dev/null
    - dest: $dest
__YAML__
    done

  cat <<__YAML__ | tee -a $ofile >/dev/null
#  notify:
__YAML__

  cat ./output/$UNIT_LIST \
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

  cat ./output/$UNIT_LIST \
  | while read -r unit; do
      cat <<__YAML__ | tee -a $ofile >/dev/null
#    - ${unit}.service
__YAML__
    done

  cat <<__YAML__ | tee -a $ofile >/dev/null
#  notify:
__YAML__

  cat ./output/$UNIT_LIST \
  | while read -r unit; do
      cat <<__YAML__ | tee -a $ofile >/dev/null
#    - Ensure ${unit} service restarted
__YAML__
    done
}

generate_templates() {
  local role_name="$1"; shift
  local rpm_pkg_name="$1"; shift

  cat ./output/$TEMPLATE_DEST_LIST \
  | while read -r line; do
      local tmpl_dest="$line"
      local tmpl_src="$role_name/templates/el7${line}.j2"
      local tmpl_src_dir=$(dirname $tmpl_src)

      mkdir -pv $tmpl_src_dir
      rpm2cpio $pkg_file \
        | cpio -i --to-stdout .$line \
        | tee $tmpl_src >/dev/null
    done
}

generate_handlers() {
  local role_name="$1"; shift
  local rpm_pkg_name="$1"; shift

  local ofile=$role_name/handlers/main.yml
  : >$ofile

  cat ./output/$UNIT_LIST \
    | while read -r unit; do
        cat <<__YAML__ | tee -a $ofile >/dev/null
- name: Ensure ${unit} service restarted
  systemd:
    name: ${unit}.service
    state: restarted

__YAML__
      done
}

main() {
  local rpm_pkg_name="$1"; shift

  tmp_dir=$(mktemp -d)
  pushd $tmp_dir >/dev/null

  mkdir -p ./rpm
  yumdownloader --destdir ./rpm $rpm_pkg_name 2>&1 >/dev/null
  pkg_file=$(readlink -f $(find ./rpm -type f))

  mkdir -pv ./output

  rpm2cpio $pkg_file \
    | cpio -it \
    | sed -e 's/^\.//' \
    >./output/cpio_it.txt

  cat \
    <(grep -P "^(/etc/|/var/lib/)" ./output/cpio_it.txt) \
    <(rpm -q -p $pkg_file -l | grep -P "^(/etc/|/var/lib/)") \
    | sort \
    | uniq --repeated \
    >./output/$TEMPLATE_DEST_LIST

  rpm -q -p $pkg_file -l \
    | grep -Po "(?<=^/usr/lib/systemd/system/).+(?=.service)" \
    >./output/$UNIT_LIST

  local role_name="ansible-role-${rpm_pkg_name}"

  ansible-galaxy init $role_name
  generate_readme $role_name $rpm_pkg_name
  generate_meta $role_name $rpm_pkg_name
  generate_tasks $role_name $rpm_pkg_name
  generate_templates $role_name $rpm_pkg_name
  generate_handlers $role_name $rpm_pkg_name
  #generate_tests $role_name $rpm_pkg_name # TODO

  if [[ $option_dry_run == 'yes' ]]; then
    find .
    echo_err "(dry run)"
  fi
  popd >/dev/null

  if [[ $option_dry_run == 'no' ]]; then
    mv -iv $tmp_dir/$role_name ./$role_name
  fi

  echo_err "removing temporary files..."
  rm -rf $tmp_dir
}

gloval_variables

while getopts -- "-:fh" OPT; do
  case $OPT in
    -)
      case $OPTARG in
        dry-run)
          option_dry_run=yes
          ;;
        force)
          option_dry_run=no
          ;;
        *)
          getopt_err_badopt $OPTARG
          usage_exit
          ;;
      esac;;
    f) option_dry_run=no;;
    h) usage_exit;;
    \?) usage_exit;;
  esac
done
shift $((OPTIND-1))

if [[ $# -ne 1 ]]; then
  usage_exit
fi

main "$*"
exit 0
