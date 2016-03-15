#!/bin/bash -e

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

source "$(dirname "${BASH_SOURCE[0]}")/common_tools.sh"

jenkins_setup_dotssh () {
  check_parameters CF_paramDnsName
  mkdir -p /var/lib/jenkins/.ssh
  chmod 700 /var/lib/jenkins/.ssh
  /opt/nitor/fetch-secrets.sh get 400 /var/lib/jenkins/.ssh/${CF_paramDnsName}.rsa
  mv -v /var/lib/jenkins/.ssh/*.rsa /var/lib/jenkins/.ssh/id_rsa
  ssh-keygen -y -f /var/lib/jenkins/.ssh/id_rsa > /var/lib/jenkins/.ssh/id_rsa.pub
  chmod 400 /var/lib/jenkins/.ssh/id_rsa.pub
  ssh-keyscan -t rsa github.com >> /var/lib/jenkins/.ssh/known_hosts
  chown -R jenkins:jenkins /var/lib/jenkins/
}

jenkins_mount_home () {
  encrypt-and-mount.sh /dev/xvdb /var/lib/jenkins/jenkins-home
  chown -R jenkins:jenkins /var/lib/jenkins/jenkins-home
}

jenkins_mount_ebs_home () {
  check_parameters CF_paramEBSTag CF_resourceDeleteSnapshotsLambda
  local SIZE=$1
  if [ -z "$SIZE" ]; then
    SIZE=32
  fi
  local MOUNT_PATH=/var/lib/jenkins/jenkins-home
  volume-from-snapshot.sh ${CF_paramEBSTag} ${CF_paramEBSTag} $MOUNT_PATH  $SIZE
  cat > /etc/cron.d/${CF_paramEBSTag}-snapshot << MARKER
30 * * * * root /usr/bin/snapshot-from-volume.sh ${CF_paramEBSTag} ${CF_paramEBSTag} $MOUNT_PATH >> /var/log/snapshots.log 2>&1
MARKER
  cat > /etc/cron.d/${CF_paramEBSTag}-clean << MARKER
45 4 * * * root /usr/bin/clean-snapshots.sh ${CF_resourceDeleteSnapshotsLambda} >> /var/log/snapshots.log 2>&1
MARKER

}

jenkins_setup_default_gitignore () {
  cat > /var/lib/jenkins-default/.gitignore << EOF
*.csv
*.log
builds
fingerprints
htmlreports
identity.key.enc
lastFailed
lastFailedBuild
lastStable
lastStable
lastStableBuild
lastSuccessful
lastSuccessfulBuild
logs
modules
outOfOrderBuilds
secret.key
secrets
workspace
jenkins.war*
EOF
  chown -R jenkins:jenkins /var/lib/jenkins-default/
}


# optional parameters: CF_paramJenkinsGit
jenkins_fetch_repo () {
  chown -R jenkins:jenkins /var/lib/jenkins
  chown -R jenkins:jenkins /var/lib/jenkins/jenkins-home
  sudo -iu jenkins git init /var/lib/jenkins/jenkins-home
  if [ "${CF_paramJenkinsGit}" ]; then
    echo "Using remote jenkins config git repo ${CF_paramJenkinsGit}"
    sudo -iu jenkins git --git-dir=/var/lib/jenkins/jenkins-home/.git remote add -f -t master \
	 origin ${CF_paramJenkinsGit}
    sudo -iu jenkins git --git-dir=/var/lib/jenkins/jenkins-home/.git \
	 --work-tree=/var/lib/jenkins/jenkins-home checkout master
  else
    echo "Created local-only jenkins config git repo"
  fi
}

jenkins_merge_default_install_with_repo () {
  if [ -e /var/lib/jenkins/jenkins-home/config.xml ]; then
    echo "Git repository contains Jenkins config - using that with base files from default installation"
    {
      cat /var/lib/jenkins-default/.gitignore
      [ ! -e /var/lib/jenkins/jenkins-home/.gitignore ] || cat /var/lib/jenkins/jenkins-home/.gitignore
    } | while read pattern ; do
	  case "$pattern" in
	    /*)
              eval mv -v /var/lib/jenkins-default${pattern} /var/lib/jenkins/jenkins-home/ ||:
	      ;;
	    *)
	      (
		cd /var/lib/jenkins-default/
		find -name "$pattern" | \
		  while read entry ; do
		    dest="/var/lib/jenkins/jenkins-home/${entry}"
		    destdir="$(dirname "${dest}")"
		    mkdir -p "$destdir"
		    mv -v "$entry" "$dest"
		  done
	      )
	      ;;
	  esac
	done
  else
    echo "Git repository empty - using default jenkins installation a base"
    mv -v /var/lib/jenkins-default/* /var/lib/jenkins-default/.??* /var/lib/jenkins/jenkins-home/
  fi
}

jenkins_setup_git_sync_script () {
  if [ ! -e /var/lib/jenkins/jenkins-home/sync_git.sh ]; then
    cat > /var/lib/jenkins/jenkins-home/sync_git.sh << EOF
#!/bin/bash -xe

/usr/bin/snapshot-from-volume.sh ${CF_paramEBSTag} ${CF_paramEBSTag} /var/lib/jenkins/jenkins-home
DIR=\$(cd \$(dirname \$0); pwd -P)
cd \$DIR
date
git add -A
git commit -m "Syncing latest changes\$COMMITMSGSUFFIX" ||:
EOF
    [ ! "${CF_paramJenkinsGit}" ] || echo 'git push origin master' >> /var/lib/jenkins/jenkins-home/sync_git.sh
  fi
  chmod 755 /var/lib/jenkins/jenkins-home/sync_git.sh
}

jenkins_setup_git_sync_on_shutdown () {
  # Amend service script to call sync_git right after stopping the service - original script saved as jenkins.orig
  if [ -n "${CF_paramJenkinsGit}" ]; then
    if [ "$SYSTEM_TYPE" = "ubuntu" ]; then
      perl -i.orig -e 'while(<>){print;if(m!^(\s+)do_stop!){print $1.'\''retval="$?"'\''."\n".$1."sudo -iu jenkins env COMMITMSGSUFFIX=\" (jenkins shutdown)\" /var/lib/jenkins/jenkins-home/sync_git.sh\n";last;}}$_=<>;s/\$\?/\$retval/;print;while(<>){print}' /etc/init.d/jenkins
    elif [ "$SYSTEM_TYPE" = "centos" -o "$SYSTEM_TYPE" = "fedora" ]; then
      perl -i.orig -e 'while(<>){print;if(m!^(\s+)killproc!){print $1.'\''retval="$?"'\''."\n".$1."sudo -iu jenkins env COMMITMSGSUFFIX=\" (jenkins shutdown)\" /var/lib/jenkins/jenkins-home/sync_git.sh\n";last;}}$_=<>;s/\$\?/\$retval/;print;while(<>){print}' /etc/init.d/jenkins
    else
      echo "Unkown system type $SYSTEM_TYPE"
    fi
  else
    if [ "$SYSTEM_TYPE" = "ubuntu" ]; then
      perl -i.orig -e 'while(<>){print;if(m!^(\s+)do_stop!){print $1.'\''retval="$?"'\''."\n".$1."/usr/bin/snapshot-from-volume.sh '${CF_paramEBSTag}' '${CF_paramEBSTag}' /var/lib/jenkins/jenkins-home\n";last;}}$_=<>;s/\$\?/\$retval/;print;while(<>){print}' /etc/init.d/jenkins
    elif [ "$SYSTEM_TYPE" = "centos" -o "$SYSTEM_TYPE" = "fedora" ]; then
      perl -i.orig -e 'while(<>){print;if(m!^(\s+)killproc!){print $1.'\''retval="$?"'\''."\n".$1."/usr/bin/snapshot-from-volume.sh '${CF_paramEBSTag}' '${CF_paramEBSTag}' /var/lib/jenkins/jenkins-home\n";last;}}$_=<>;s/\$\?/\$retval/;print;while(<>){print}' /etc/init.d/jenkins
    else
      echo "Unkown system type $SYSTEM_TYPE"
    fi
  fi
}

jenkins_setup_git_sync_job () {
  if ! find /var/lib/jenkins/jenkins-home/jobs -name config.xml -print0 | xargs -0 fgrep -q sync_git.sh ; then
    sync_jenkins_conf_job_name="sync-jenkins-conf-to-git"
    mkdir -p /var/lib/jenkins/jenkins-home/jobs/${sync_jenkins_conf_job_name}
    cat > /var/lib/jenkins/jenkins-home/jobs/${sync_jenkins_conf_job_name}/config.xml << 'EOF'
<?xml version='1.0' encoding='UTF-8'?>
<project>
  <actions/>
  <description>Runs the &quot;sync_git.sh&quot; script that pushes the latest jenkins config to the remote Jenkins repo.</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <jenkins.model.BuildDiscarderProperty>
      <strategy class="hudson.tasks.LogRotator">
        <daysToKeep>60</daysToKeep>
        <numToKeep>-1</numToKeep>
        <artifactDaysToKeep>-1</artifactDaysToKeep>
        <artifactNumToKeep>-1</artifactNumToKeep>
      </strategy>
    </jenkins.model.BuildDiscarderProperty>
  </properties>
  <scm class="hudson.scm.NullSCM"/>
  <canRoam>true</canRoam>
  <disabled>true</disabled>

  <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
  <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
  <triggers>
    <hudson.triggers.TimerTrigger>
      <spec>H H(18-19) * * *
H H(4-5) * * *</spec>
    </hudson.triggers.TimerTrigger>
  </triggers>
  <concurrentBuild>false</concurrentBuild>
  <builders>
    <hudson.tasks.Shell>
      <command>/var/lib/jenkins/jenkins-home/sync_git.sh 2&gt;&amp;1 | tee -a /var/lib/jenkins/sync_git.log</command>
    </hudson.tasks.Shell>
  </builders>
  <publishers/>
  <buildWrappers/>
</project>
EOF
  fi
}

jenkins_git_commit () {
  chown -R jenkins:jenkins /var/lib/jenkins
  sudo -iu jenkins git --git-dir=/var/lib/jenkins/jenkins-home/.git \
       --work-tree=/var/lib/jenkins/jenkins-home add .
  sudo -iu jenkins git --git-dir=/var/lib/jenkins/jenkins-home/.git \
       --work-tree=/var/lib/jenkins/jenkins-home commit -m 'Post-installation commit' ||:
}

jenkins_discard_default_install () {
  rm -rf /var/lib/jenkins-default
}

jenkins_fetch_additional_files () {
  /opt/nitor/fetch-secrets.sh get 400 ${CF_paramAdditionalFiles}
  for i in ${CF_paramAdditionalFiles} ; do
    case "$i" in
      /var/lib/jenkins/*)
	chown -R jenkins:jenkins "$i"
	;;
    esac
  done
}

jenkins_improve_config_security () {
  mkdir -p /var/lib/jenkins/jenkins-home/secrets/
  echo false > /var/lib/jenkins/jenkins-home/secrets/slave-to-master-security-kill-switch
}

jenkins_set_home () {
  case "$SYSTEM_TYPE" in
    ubuntu)
      local SYSCONFIG=/etc/default/jenkins
      ;;
    centos|fedora)
      local SYSCONFIG=/etc/sysconfig/jenkins
      ;;
    *)
      echo "Unkown system type $SYSTEM_TYPE"
      exit 1
  esac
  sed -i 's/JENKINS_HOME=.*/JENKINS_HOME=\/var\/lib\/jenkins\/jenkins-home/g' $SYSCONFIG
}

jenkins_disable_and_shutdown_service () {
  case "$SYSTEM_TYPE" in
    ubuntu)
      update-rc.d jenkins disable
      service jenkins stop
      ;;
    centos|fedora)
      systemctl disable jenkins
      systemctl stop jenkins
      ;;
    *)
      echo "Unkown system type $SYSTEM_TYPE"
      exit 1
  esac
}

jenkins_enable_and_start_service () {
  case "$SYSTEM_TYPE" in
    ubuntu)
      update-rc.d jenkins enable
      service jenkins start
      ;;
    centos|fedora)
      systemctl enable jenkins
      systemctl start jenkins
      ;;
    *)
      echo "Unkown system type $SYSTEM_TYPE"
      exit 1
  esac
}

jenkins_wait_service_up () {
  # Tests to see if everything is OK
  COUNT=0
  SERVER=""
  while [ $COUNT -lt 300 ] && [ "$SERVER" != "Jenkins" ]; do
    sleep 1
    SERVER="$(curl -sv http://localhost:8080 2>&1 | grep 'X-Jenkins:' | awk -NF'-|:' '{ print $2 }')"
    COUNT=$(($COUNT + 1))
  done
  if [ "$SERVER" != "Jenkins" ]; then
    fail "Jenkins server not started"
  fi
}
