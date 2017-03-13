#!/bin/bash

if [ -z "$1" ]; then
  cat <<EOF
usage:
  ./make_spec.sh PACKAGE
EOF
  exit 1
fi

cd $(dirname $0)

YEAR=$(date +%Y)
VERSION=$(cat ../../VERSION)
COMMIT_UNIX_TIME=$(git show -s --format=%ct)
VERSION="${VERSION%+*}+$(date -d @$COMMIT_UNIX_TIME +%Y%m%d).$(git rev-parse --short HEAD)"
NAME=$1
GITREPONAME=$(basename `git rev-parse --show-toplevel`)

cat <<EOF > ${NAME}.spec
#
# spec file for package $NAME
#
# Copyright (c) $YEAR SUSE LINUX GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

%{!?tmpfiles_create:%global tmpfiles_create systemd-tmpfiles --create}

Name:           $NAME
%define gitrepo $GITREPONAME
Version:        $VERSION
Release:        0
BuildArch:      noarch
Summary:        Production-Grade Container Scheduling and Management
License:        Apache-2.0
Group:          System/Management
Url:            https://github.com/kubic-project/salt
Source:         master.tar.gz
BuildRequires:  systemd-rpm-macros
Requires:       salt
Requires:       python-m2crypto

%description
Salt scripts for deploying a Kubernetes cluster

%prep
%setup -q -n %{gitrepo}-master

%build

%install
rm -rf %{buildroot}%{_datadir}
mkdir -p %{buildroot}%{_datadir}/salt/kubernetes
cp -R %{_builddir}/%{gitrepo}-master/*  %{buildroot}%{_datadir}/salt/kubernetes/

%files
%defattr(-,root,root)
%dir %{_datadir}/salt
%dir %{_datadir}/salt/kubernetes
%{_datadir}/salt/kubernetes/*

%changelog
EOF
