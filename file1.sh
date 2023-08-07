#!/bin/bash
	
echo "********* Add sudo user **********"
sudo adduser bob
sudo usermod -aG sudo bob
id bob
su - bob

echo "********* Create a directory: files **********"
mkdir files

echo "********* Install unzip **********"
sudo apt install unzip

echo "********* Download AzureArc.ps1 file **********"
wget "https://raw.githubusercontent.com/lcoul/AzureDemoLab/main/Scripts/AzureArc.ps1" -P files/
