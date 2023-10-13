if [ $# == 0 ]; then 
    if odin build . -o:speed; then
        echo "Build release version."
    else
        echo -e "\033[31mFailed to build release version."
    fi
elif [ $1 == "d" ]; then 
    if odin build . -debug; then
        echo "Build debug version."
    else
        echo -e "\033[31mFailed to build debug version."
    fi
elif [ $1 == "i" ]; then 
    if odin build . -o:speed; then
        # personal thing
        cp ./cody.exe /d/softw/toolkit
        echo "Build release version and install."
    else
        echo -e "\033[31mFailed to build release version and install."
    fi
else
    echo -e "\033[31mInvalid args."
fi