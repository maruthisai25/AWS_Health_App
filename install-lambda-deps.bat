@echo off
echo Installing Lambda function dependencies...

cd applications\lambda-functions

echo Installing auth-handler dependencies...
cd auth-handler
call npm install
cd ..

echo Installing pre-signup dependencies...
cd pre-signup
call npm install
cd ..

echo Installing post-confirmation dependencies...
cd post-confirmation
call npm install
cd ..

echo Installing chat-resolver dependencies...
cd chat-resolver
call npm install
cd ..

echo Installing message-processor dependencies...
cd message-processor
call npm install
cd ..

echo Installing chat-auth-resolver dependencies...
cd chat-auth-resolver
call npm install
cd ..

echo Installing video-processor dependencies...
cd video-processor
call npm install
cd ..

echo Installing presigned-url-generator dependencies...
cd presigned-url-generator
call npm install
cd ..

echo Installing attendance-tracker dependencies...
cd attendance-tracker
call npm install
cd ..

echo Installing attendance-reporter dependencies...
cd attendance-reporter
call npm install
cd ..

echo Installing notification-handler dependencies...
cd notification-handler
call npm install
cd ..

echo Installing email-sender dependencies...
cd email-sender
call npm install
cd ..

echo All Lambda dependencies installed successfully!
cd ..\..