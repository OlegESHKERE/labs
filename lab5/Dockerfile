# Use the official Tomcat 9 base image
FROM tomcat:9.0-jre11

# Set environment variables (optional)
ENV CATALINA_HOME /usr/local/tomcat
ENV PATH $CATALINA_HOME/bin:$PATH

# Remove existing ROOT webapp and create a new one with a simple index.html
RUN rm -rf $CATALINA_HOME/webapps/ROOT && \
    mkdir $CATALINA_HOME/webapps/ROOT && \
    echo '<!DOCTYPE html><html><head><title>Welcome to Tomcat</title></head><body><h1>TOMCAT at your service!</h1><p>This is the default Tomcat page.</p></body></html>' > $CATALINA_HOME/webapps/ROOT/index.html

# Expose port 8080 for external access
EXPOSE 8080

# Start Tomcat server
CMD ["catalina.sh", "run"]

