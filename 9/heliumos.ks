# network configuration
network --bootproto=dhcp --device=link --activate

# Partioning Setup
clearpart --all --initlabel --disklabel=gpt
reqpart --add-boot
part / --grow --fstype ext4

# -- Disable Kdump --
%addon com_redhat_kdump --disable
%end

# --- Container Image Installation --
ostreecontainer --url quay.io/heliumos/bootc:9

# --- Basic Security ---
firewall --enabled

rootpw --iscrypted locked #Disable direct root password login

%post

rm -f /var/lib/systemd/random-seed

%end
