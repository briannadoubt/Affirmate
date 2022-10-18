# deploy.sh

# Build the container using Cloud Build, giving plenty of time for the `swift build` step
gcloud builds submit --tag gcr.io/affirmate-364918/affirmate --timeout="1h"

# Run the container
gcloud run deploy vapor --image gcr.io/affirmate-364918/affirmate --platform managed --allow-unauthenticated