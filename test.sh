	echo "Downloading wallet..."
	mkdir /root/smrtc
  	cd smrtc
	mkdir /root/.smrtc
	wget https://github.com/telostia/smartcloud-guides/releases/download/0.001/smrtc-linux.tar.gz
	tar -xvf smrtc-linux.tar.gz
	rm /root/ucc/smrtc-linux.tar.gz
	cp smrtcd /root/smrtc/smrtcd
	cp smrtc-cli /root/smrtc/smrtc-cli
	rm -rf smrtc-linux.tar.gz/
	rm -rf /root/smrtc/smrtc-linux.tar.gz/
	chmod +x /root/smrtc/
	chmod +x /root/smrtc/smrtcd
	chmod +x /root/smrtc/smrtc-cli
	echo "Done..."
}
