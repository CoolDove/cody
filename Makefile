debug:
	odin build . -debug;
release:
	odin build . -o:speed
install: release
	cp ./cody.exe /d/softw/toolkit	
clean:
	rm cody.exe cody.pdb
