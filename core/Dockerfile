FROM ballerina/ballerina:1.2.3

WORKDIR /env_platform

COPY ./target/bin .
EXPOSE 9090

CMD ["ballerina", "run", "env_platform.jar"]
