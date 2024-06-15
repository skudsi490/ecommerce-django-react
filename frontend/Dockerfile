# Use the official Node.js image based on Debian Buster
FROM node:20-buster as build

# Set the working directory
WORKDIR /app

# Copy package.json and install dependencies
COPY ./frontend/package.json /app/package.json
RUN npm install

# Copy the rest of the application code
COPY ./frontend /app/

# Update browserslist database
RUN npx browserslist@latest --update-db

# Build the application
RUN npm run build

# Use Nginx to serve the build
FROM nginx:alpine
COPY --from=build /app/build /usr/share/nginx/html
COPY ./frontend/nginx.conf /etc/nginx/nginx.conf
