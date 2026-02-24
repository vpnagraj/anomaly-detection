# Anomaly Detection on Time Series Data

When a new batch of time series observations arrives — IoT sensor readings, 
server metrics, weather station data, financial tick data — the instance 
runs an anomaly detection pass using something like scikit-learn's IsolationForest 
or a simple Z-score method, then writes back a scored version of the file where 
each row is annotated with an anomaly flag and a score. The more interesting 
extension is that the instance maintains a running statistical baseline in S3 
(a small JSON file tracking rolling mean and standard deviation per sensor/channel), 
which it updates with each new batch. This means the detection gets smarter over 
time without any retraining, just adaptive statistics. Students get to think about 
stateful stream-like processing even though the transport mechanism is batch files — 
a useful conceptual bridge toward real streaming systems.

- - -

## Setup

First, fork this repository to own and manage your own copy.

Second, you must bootstrap the instance so that `BUCKET_NAME` is 
available as a global environment variable. (The name of this bucket is what your
IaC template(s) will create on your bahalf.) Setting a global environment variable 
can be done by adding the `KEY="VALUE"` into `/etc/environment`. The application will 
not run without an S3 bucket and an IAM role allowing it read/write access to the bucket.

The following files support the detection and get imported as classes or called by
the main API:
```
baseline.py
detector.py
processor.py
```

The running service is a FastAPI application, found in `app.py` that provides five
endpoints:
- POST `/notify` — receives SNS messages; handles the subscription confirmation handshake and dispatches incoming S3 object keys to process_file as a background task
- GET `/anomalies/recent` — scans the 10 most recent processed CSVs and returns rows where anomaly == True, with a limit query parameter
- GET `/anomalies/summary` — aggregates the _summary.json files to give a high-level view of total rows scored, total anomalies, and overall anomaly rate across all batches
- GET `/baseline/current` — shows the live per-channel statistics (mean, std, observation count, and whether the baseline is mature yet)
- GET `/health` — simple liveness check, useful for confirming the service came up correctly after bootstrap

To run this bundled application, you must:
- Create and activate a virtual environment using `virtualenv` or `pipenv`, etc.
- Install Python dependencies into that environment, found in `requirements.txt`.
- Run the FastAPI application using this syntax from within the directory where `app.py` exists:

    ```
    fastapi run app.py --reload
    ```
  Remember that the `python` or `fastapi` binaries for a virtual environment have their own paths that can be called from outside of the activated virtual environment.

The running application, as it receives and digests test files, records cumulative 
state in a file named `baseline.json` which it also regularly pushes back to your 
bucket in `s3://BUCKET_NAME/state/baseline.json`.

## Testing

A test script `test_producer.py` is provided that should be run on your local laptop or from within another
SSH session on your instance. Note that it has its own dependencies.

