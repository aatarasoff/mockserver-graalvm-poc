# mockserver-graalvm-poc
Experimental repository for the article https://medium.com/@aatarasoff/graalvm-native-image-real-life-d20689dbdb77

## Build repacked image
```
docker build -t mockserver-repacked -f Dockerfile.repacked .
```

## Run repacked image
```
docker run -d -p 8000:8000 -v $PWD/traces:/traces mockserver-repacked java -server -Xms1024m -Xmx1024m -agentlib:native-image-agent=trace-output=/traces/trace-log-custom.json -jar /mockserver-netty-jar-with-dependencies.jar -serverPort 8000
```

Feel free to change JVM opts.

## Run expectations and apps that use mocks

For example fetch healthcheck
```
http localhost:8000/api/healthcheck
```

This is required to fill `/traces/trace-log-custom.json` to build native image.
Then you should stop docker container:
```
docker stop <container_id>
```

## Build native image
```
docker build -t mockserver-native .
```

## Run native image
```
docker run -d -p 8000:8000 mockserver-native
```
