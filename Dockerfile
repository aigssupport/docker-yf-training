########################################################################################################
#
# Yellowfin Application-Server Only Docker File
#
# An image that will create a new application server node, and connect to an existing Yellowfin
# repository database.
#
# Options can be passed to the image on startup with the -e command
#
#  JDBC_CLASS_NAME                 The java class file for the repository database JDBC connection
#
#  JDBC_CONN_URL                   The JDBC connection string for the repository database
#
#  JDBC_CONN_USER                  The JDBC user for the repository database
#
#  JDBC_CONN_PASS                  The JDBC password for the repository database (can be encrypted)
#
#  JDBC_CONN_ENCRYPTED (Optional)  Whether the database password is encrypted or not. Defaults to false
#
#  JDBC_MAX_COUNT (Optional)       Maximum connection pool size for the repository database connection pool. Defaults to 25
#
#  WELCOME_PAGE (Optional)         The default landing page for the application. Defaults to index_mi.jsp
#
#  APP_SERVER_PORT (Optional)      The HTTP port for the application. Defaults to 8080
#
#  APP_SHUTDOWN_PORT (Optional)    The shutdown port for the application. Defaults to 8083
#
#######################################################################################################


#######################################################################################################
# Fetch the base operating system
#
# The installer can be downloaded during provisioning, or by providing the JAR file as part of image
#######################################################################################################

# From Ubuntu 20 base image
FROM ubuntu:20.04
LABEL maintainer="AIGS Support <support@aigs.co.za>"
LABEL description="AIGS Insights Training"

# Timezone setup
ENV TZ=Africa/Johannesburg
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install OS applications required for application installation and setup Java
RUN apt update && apt install unzip tar curl sed ttf-dejavu fonts-dejavu \
 fontconfig libasound2 libglib2.0-0 libpangoft2-1.0-0 -y
 
#Configure Java 11 using Zulu 11 JDK
RUN mkdir /usr/lib/jvm -p 
COPY zulu11.41.23-ca-fx-jdk11.0.8-linux_x64.tar.gz /usr/lib/jvm/zulu11.tar.gz
RUN cd /usr/lib/jvm/ && tar -xzvf zulu11.tar.gz && mv zulu11.41* zulu11-jdk/ && rm zulu11.tar.gz

ENV JAVA_HOME=/usr/lib/jvm/zulu11-jdk/
ENV PATH="$JAVA_HOME/bin:$PATH"


#######################################################################################################
# Fetch the Yellowfin installer
#
# The installer can be downloaded during provisioning, or by providing the JAR file as part of image
#######################################################################################################

# Download Yellowfin installer JAR
# (This may slow down image creation time)
# RUN curl -qL https://files.yellowfin.bi/downloads/9.3/yellowfin-9.3.0-20201008-full.jar -o /tmp/yellowfin.jar

# Alternatively copy in an installer that has been included image
# (This will remove the wait time for downloading the installer during image creation)
# Example syntax for copying in an embedded installer:
COPY yellowfin-9.8.1.1-20221220-full.jar /tmp/yellowfin.jar

#######################################################################################################
# Perform filesystem installation
#
# Extract assets directly from Yellowfin installer JAR onto filesystem.
#######################################################################################################

# Create working directory structure
RUN mkdir -p /opt/yellowfin /tmp/yftemp /tmp/yftemp2/appserver/webapps/ROOT /opt/yellowfin/appserver/logs

# Perform application extraction
RUN unzip /tmp/yellowfin.jar -d /tmp/yftemp && unzip /tmp/yftemp/yfres/yellowfin.zip -d /tmp/yftemp2 \
&& unzip /tmp/yftemp2/yellowfin.war -d /tmp/yftemp2/appserver/webapps/ROOT \
&& cp /tmp/yftemp/yfres/jdbc-drivers/* /tmp/yftemp2/appserver/webapps/ROOT/WEB-INF/lib \
&& rm /tmp/yftemp2/yellowfin.war && cp -a /tmp/yftemp2/* /opt/yellowfin/ \
# && unzip /tmp/yftemp/yfres/skiteam.zip -d /opt/yellowfin/ \
&& rm -rf /tmp/yftemp /tmp/yftemp2 /tmp/yellowfin.jar
RUN chmod +x /opt/yellowfin/appserver/bin/catalina.sh /opt/yellowfin/appserver/bin/startup.sh /opt/yellowfin/appserver/bin/shutdown.sh

# Perform training extraction
COPY training-configdb.zip /tmp/training-configdb.zip
RUN unzip -o /tmp/training-configdb.zip -d /opt/yellowfin/
COPY training-tutorialdata.zip /tmp/training-tutorialdata.zip
RUN unzip -o /tmp/training-tutorialdata.zip -d /opt/yellowfin/

ENV JDBC_CLASS_NAME=org.hsqldb.jdbcDriver
ENV JDBC_CONN_URL=jdbc:hsqldb:file:/opt/yellowfin/data/configdb;shutdown=true
ENV JDBC_CONN_USER=SA
ENV JDBC_CONN_PASS=cDahEHuTOrk=
ENV JDBC_CONN_ENCRYPTED=true
ENV JDBC_CONN_ENCRYPTED=true
ENV APP_MEMORY=4096

#######################################################################################################
# Configuration
#
# Modify Yellowfin's configuration based on parameters passed to the docker container.
#######################################################################################################

COPY perform_docker_configuration.sh /opt/yellowfin/appserver/bin
RUN chmod +x /opt/yellowfin/appserver/bin/perform_docker_configuration.sh
RUN sed -i 's/exec "$PRGDIR"\/"$EXECUTABLE" start "$@"/\/opt\/yellowfin\/appserver\/bin\/perform_docker_configuration.sh\nexec "$PRGDIR"\/"$EXECUTABLE" run "$@"/g' /opt/yellowfin/appserver/bin/startup.sh

#######################################################################################################
# Installation Customization
#
# Copy and configure additional assets for the Yellowfin installation. This could include:
#
# - Providing support for additional databases (by including JDBC drivers)
# - Providing custom styling
# - Providing a custom index page
# - Providing additional plug-ins (third-party sources, analytic functions, formatters etc)
# - Providing a SSL certificate to tomcat
#
#######################################################################################################


# Install additional Yellowfin dependencies, including JDBC Drivers and custom plugins
# Example of downloading drivers at startup time:
# RUN curl -qL "https://cdn.mysql.com//Downloads/Connector-J/mysql-connector-java-8.0.18.tar.gz" | tar --strip=1 -C /opt/yellowfin/appserver/lib/ -xz mysql-connector-java-8.0.18/mysql-connector-java-8.0.18.jar
# RUN curl -qL "https://jdbc.postgresql.org/download/postgresql-42.2.8.jar" -o /opt/yellowfin/appserver/lib/postgresql-42.2.8.jar

# Example of copying in drivers that are part of the docker image:
# COPY postgresql-42.2.8.jar /opt/yellowfin/appserver/lib/postgresql-42.2.8.jar


#######################################################################################################
# Launch Yellowfin
#
# Start the Yellowfin application.
#######################################################################################################
WORKDIR /opt/yellowfin/appserver/bin
CMD ["/opt/yellowfin/appserver/bin/startup.sh"]
EXPOSE 8080
