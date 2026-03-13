FROM nginx:alpine

# Remove default nginx static assets
RUN rm -rf /usr/share/nginx/html/*

# Copy site files
COPY index.html /usr/share/nginx/html/
COPY fonts/ /usr/share/nginx/html/fonts/
COPY app-previews/ /usr/share/nginx/html/app-previews/

# Custom nginx config for SPA-style single-file site
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080
