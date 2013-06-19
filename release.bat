@echo off
rd /s/q release
md release
xcopy src\. release\. /s
md release\samples
echo bin>exc.txt
echo .iml>>exc.txt
xcopy samples\. release\samples\. /s/exclude:exc.txt
del exc.txt
