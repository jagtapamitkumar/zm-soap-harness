#!/usr/bin/env perl
# $File$ 
# $DateTime$
#
# $Revision$
# $Author$
# $Modified by: gzhang in revision #8 $
#
use File::Basename;
use IPC::Open2;


sub apt_get {
  my @command_list = @_;
  open (PIPE, "-|", 'DEBIAN_FRONTEND=noninteractive apt-get '.join(' ', @command_list)) || die $!;
  while(<PIPE>) {
    print;
  }
  close PIPE;
}
  
  
sub update_apt {
  open FILE, '>> /etc/apt/sources.list' || die $!;
  printf FILE join("", <DATA>);
  close FILE;
  printf "Funning apt-get\n";
 
}

sub install_packages {
  &apt_get('update');
  my @package_list = ('nfs-common', 'sun-java5-jdk', 'ruby', 'libopenssl-ruby', 'libjson-ruby', 'libldap-ruby1.8'
		      , 'libhttp-access2-ruby', 'liblog4r-ruby', 'soap4r', 'binutils');
  my $item = '';
  foreach $item (@package_list) {
    &apt_get('-y', 'install', $item);
  }
}

sub install_test_license {
  printf "Get a copy of old license\n";
  `su - zimbra -c '/opt/zimbra/bin/zmlicense -p > /var/tmp/old_license.xml'`;
  printf "Fetching license\n";
  my $fetch_command = 'wget --no-proxy -O /opt/zimbra/conf/regular.xml --no-check-certificate https://zimbra-stage-license-vip.vmware.com/zimbraLicensePortal/QA/LKManager'.
  ' --post-data="AccountsLimit=-1&ArchivingAccountsLimit=-1&AttachmentIndexingAccountsLimit=-1&ISyncAccountsLimit=-1&MAPIConnectorAccountsLimit=-1&MobileSyncAccountsLimit=-1&SMIMEAccountsLimit=-1&InstallType=regular"';
  open(PIPE, "-|", $fetch_command) || die $!;
  while(<PIPE>) {
    print;
  }
  close PIPE;
  `chmod ugo+r /opt/zimbra/conf/regular.xml`;
  print "Installing license\n";
  `su - zimbra -c '/opt/zimbra/bin/zmlicense -i /opt/zimbra/conf/regular.xml'`;
  `su - zimbra -c '/opt/zimbra/bin/zmlicense -a'`;
  print `su - zimbra -c '/opt/zimbra/bin/zmlicense -p'`;
  print `su - zimbra -c '/opt/zimbra/bin/zmprov fc license'`;
}

sub setup_mount {
  my @command_list = ('mkdir -p /opt/qa/testlogs', 'mkdir -p /opt/qa/testware', "echo '10.137.245.250:/Zqa1/testlogs /opt/qa/testlogs nfs nfsvers=3,proto=tcp,rw,hard,intr 0 0' >> /etc/fstab", "echo '10.137.245.250:/Zqa1/testware /opt/qa/testware nfs nfsvers=3,proto=tcp,ro,hard,intr 0 0' >> /etc/fstab","mount -a");
  foreach my $item (@command_list) {
    print "Running: ", $item, "\n";
    print `$item`;
  }
}

sub setup_profile {
 print "Update profile\n";
 print `wget --no-proxy -O /var/tmp/profile.txt http://zqa-tms.eng.vmware.com/files/profile.txt`;
 print `cat /var/tmp/profile.txt >> /etc/profile`;
}

sub accept_java_eula {
  my @pack_list = ('sun-java5-jdk', 'sun-java5-jre', 'sun-java6-jdk', 'sun-java6-jre');
  open(PIPE, "|-", "/usr/bin/debconf-set-selections") || die $!;
  foreach my $item (@pack_list) {
    printf PIPE "$item shared/accepted-sun-dlj-v1-1 select true\n";
  }
  close PIPE;
}

sub set_sym_links {
  my @link_list = ('/usr/local/bin/ruby', '/bin/env');
  foreach my $item (@link_list) {
    my $filename = basename($item);
    my $command = "ln -s `which $filename` $item";
    print `$command`;
  }
}

sub remove_mesg {
  # remove input is not tty error in some test run
  print `sed -e "s/mesg n/#mesg n/" -i /root/.profile`;
}

sub wait_for_install {
  # check for complete
  local (*Reader, *Writer);
  my $filename = '/opt/zimbra/log/appliance_config.log';
  $filename = '/opt/zcs-installer/log/appliance_config.log' unless(-e $filename); 
  my $pid = open2(\*Reader, \*Writer, "tail -f ".$filename);
  eval {
    local $SIG{ALRM} = sub {die "timeout\n" };
    alarm 1800; #30 mins
    while(<Reader>) {
      last if /COMPLETE/;
    }
    alarm 0;
  };
  kill $pid;
  close Reader;
  close Writer;
}

sub chmod_staf {
  `chmod -R go-w /usr/local/staf`;
}

sub chmod_staf_cmd {
  print `wget --no-proxy -O /usr/local/STAF330-linux-amd64.tar.gz http://zqa-tms.eng.vmware.com/files/STAF330-linux-amd64.tar.gz`; 
  print `cd /usr/local; tar -zxvf ./STAF330-linux-amd64.tar.gz`;                                                        
  `chmod -R go-w /usr/local/staf`;
  print `ln -s /usr/local/staf/bin/STAF /usr/local/staf/bin/staf`; # export PATH=/usr/local/staf/bin:$PATH #need?
}

sub create_user_account {
   my $account_name = 'qa_test@'.`su - zimbra -c zmhostname`;
   chomp $account_name;
   my $command_string = "/opt/zimbra/bin/zmprov ca $account_name test123 zimbraIsAdminAccount TRUE";
   print `su - zimbra -c '$command_string'`;
}

sub firewall_related {
  printf "Open ports for testing due to Firewall \n";
  print `sed -e "s/\(# don't delete the 'COMMIT.*\)/-A ufw-after-input -p tcp --dport 3129 -j ACCEPT\\n-A ufw-after-input -p tcp --dport 6500 -j ACCEPT\\n-A ufw-after-input -p tcp --dport 6550 -j ACCEPT\\n$1/" -i /etc/ufw/after.rules`;
}

sub setup_rc_local_cmd {
  print "Update rc.local\n";
  print `sed -e "s/exit 0//" -i /etc/rc.local`;
  print `wget --no-proxy -O /var/tmp/rc_local.txt http://zqa-tms.eng.vmware.com/files/boot.txt`;
  print `cat /var/tmp/rc_local.txt >> /etc/rc.local`;
  print `echo 'exit 0' >> /etc/rc.local`;
  system(". /etc/rc.local");  # run this if use bootapp.pl on cmd 

}

sub setup_proxy_env_cmd {
  print "Update /etc/environment \n";
  my $env_file = "/etc/environment";
  my @proxy_list = ('export http_proxy=http://proxy.vmware.com:3128', 'export HTTP_PROXY=http://proxy.vmware.com:3128', 'export no_proxy=.eng.vmware.com,.vmware.com');
  
  open ENVFILE, ">>$env_file" or die "cannot open environment file $env_file for append: $!";

  foreach my $item (@proxy_list) {

    printf ENVFILE "$item \n";
  }

  close ENVFILE;

}



$| = 1;
&firewall_related;
#&setup_proxy_env_cmd; # When invoke bootapp.pl from cmd
&update_apt;
&accept_java_eula;
&wait_for_install;
sleep 300; #force sleep five minutes basically the system needs to wait for all the service to come up
           # this involves zmcontrol status scan, not implemented.
&install_packages;
&install_packages; #apt-get is flaky, sometimes java fails to install
&install_test_license;
&setup_mount;
&setup_profile;
&set_sym_links;
&remove_mesg;
&chmod_staf;           # 
#&chmod_staf_cmd;      # When invoke bootapp.pl from cmd, use chmod_staf_cmd instead of chmod_staf 
&create_user_account;
#&setup_rc_local_cmd;  # When invoke bootapp.pl from cmd -> logout -> login -> "staf localhost ping ping"
printf "Completed\n"; #This has to be here to signal expect script
__END__
deb http://us.archive.ubuntu.com/ubuntu/ hardy universe
deb-src http://us.archive.ubuntu.com/ubuntu/ hardy universe
deb http://us.archive.ubuntu.com/ubuntu/ hardy-updates universe
deb-src http://us.archive.ubuntu.com/ubuntu/ hardy-updates universe
deb http://us.archive.ubuntu.com/ubuntu/ hardy multiverse
deb-src http://us.archive.ubuntu.com/ubuntu/ hardy multiverse
deb http://us.archive.ubuntu.com/ubuntu/ hardy-updates multiverse
deb-src http://us.archive.ubuntu.com/ubuntu/ hardy-updates multiverse