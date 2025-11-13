# Use the official NGINX base image
FROM nginx:1.29.3-alpine

# Set a working directory
WORKDIR /etc/nginx

# Copy your custom nginx.conf to the container
COPY nginx.conf /etc/nginx/nginx.conf

# Expose default HTTP
EXPOSE 80

# Start NGINX in the foreground
CMD ["nginx", "-g", "daemon off;"]