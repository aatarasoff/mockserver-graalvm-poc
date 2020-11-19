# build repacked image
FROM jamesdbloom/mockserver:mockserver-5.10.0 as build

WORKDIR /opt/mockserver

RUN jar xvf mockserver-netty-jar-with-dependencies.jar
COPY keyToValue.json keyToMultiValue.json org/mockserver/model/schema/
RUN rm ./mockserver-netty-jar-with-dependencies.jar && \
    jar cmf META-INF/MANIFEST.MF ./mockserver-netty-jar-with-dependencies.jar *

# native build image
FROM oracle/graalvm-ce:20.1.0-java11-ol8 as native-build

# copy in jar
COPY --from=build /opt/mockserver/mockserver-netty-jar-with-dependencies.jar /

WORKDIR /opt/graalvm

RUN gu install native-image

COPY mockserver.properties init.json reflect-custom.json resource-custom.json /traces/trace-log-custom.json ./
RUN ls -la && mkdir mockserver && mkdir mockserver/native-configure

RUN java --add-exports jdk.internal.vm.compiler/org.graalvm.compiler.phases.common=ALL-UNNAMED \
         --add-exports jdk.internal.vm.ci/jdk.vm.ci.meta=ALL-UNNAMED \
         -cp /opt/graalvm-ce-java11-20.1.0/lib/graalvm/svm-agent.jar:/opt/graalvm-ce-java11-20.1.0/lib/svm/builder/svm.jar com/oracle/svm/configure/ConfigurationTool \
         generate --resource-input=resource-custom.json --reflect-input=reflect-custom.json --trace-input=trace-log-custom.json --output-dir=./mockserver/native-configure

RUN cat ./mockserver/native-configure/reflect-config.json
RUN cat ./mockserver/native-configure/resource-config.json

RUN native-image --verbose --no-server -Dnative-image.xmx=6g \
                 --static --allow-incomplete-classpath --no-fallback \
                 --report-unsupported-elements-at-runtime \
                 --initialize-at-build-time=org.slf4j \
                 -cp mockserver -jar /mockserver-netty-jar-with-dependencies.jar \
                 -Dfile.encoding=UTF-8 -Dio.netty.noUnsafe=false \
                 -H:IncludeResourceBundles=com.sun.org.apache.xml.internal.res.XMLErrorResources,com.sun.org.apache.xerces.internal.impl.msg.XMLMessages \
                 -H:ReflectionConfigurationFiles=/opt/graalvm/mockserver/native-configure/reflect-config.json \
                 -H:ResourceConfigurationFiles=/opt/graalvm/mockserver/native-configure/resource-config.json \
                 -H:JNIConfigurationFiles=/opt/graalvm/mockserver/native-configure/jni-config.json \
                 -H:ConfigurationFileDirectories=/opt/graalvm/mockserver/native-configure \
                 mockserver-native

#runtime image
FROM alpine
# expose ports.
EXPOSE 8000

WORKDIR /opt/mockserver
COPY --from=native-build /opt/graalvm/mockserver-native .
COPY mockserver.properties init.json ./

CMD ["/opt/mockserver/mockserver-native", "-logLevel", "INFO", "-serverPort", "8000"]
