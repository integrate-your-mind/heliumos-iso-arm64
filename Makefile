help:
	@echo -- HeliumOS ISO --
	@echo Requires: lorax
	@echo make fetch-N - Fetch upstream iso \(N is one of 9, 10\)
	@echo make patch-N - Patch upstream iso to produce final iso
	@echo make create-N - Fetch if needed, then patch


fetch-9:
	rm -f upstream-9.iso
	curl -o upstream-9.iso -J -L https://repo.almalinux.org/development/almalinux/9/bootc/isos/x86_64/AlmaLinux-9-latest-x86_64-boot.iso

patch-9:
	rm -f new.iso
	rm -rdf 9/images && mkdir 9/images
	cd 9/product && find . | cpio -c -o | gzip -9cv > ../images/product.img
	mkksiso --add 9/images --add 9/isolinux --add 9/EFI --volid heliumos-boot --ks 9/heliumos.ks upstream-9.iso new.iso
	mv new.iso HeliumOS-9-latest-x86_64-boot.iso

create-9:
	if [ -e upstream-9.iso ] ; then echo "Upstream iso present" ; else make fetch-9 ; fi
	make patch-9


fetch-10:
	rm -f upstream-10.iso
	curl -o upstream-10.iso -J -L https://odcs.stream.centos.org/stream-10/production/latest-CentOS-Stream/compose/BaseOS/x86_64/iso/CentOS-Stream-10-20240904.1-x86_64-boot.iso

patch-10:
	rm -f new.iso
	rm -rdf 10/images && mkdir 10/images
	cd 10/product && find . | cpio -c -o | gzip -9cv > ../images/product.img
	mkksiso --add 10/images --add 10/isolinux --add 10/EFI --volid heliumos-boot --ks 10/heliumos.ks upstream-10.iso new.iso
	mv new.iso HeliumOS-10-latest-x86_64-boot.iso

create-10:
	if [ -e upstream-10.iso ] ; then echo "Upstream iso present" ; else make fetch-10 ; fi
	make patch-10
