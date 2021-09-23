# Test

After a successful deployment, the `Test/test-via-pipeline.sh` can be run.
Just provide the path of the `parameters.json`.

This test requires you to have at least a contributor role.

## Usage

```sh
bash ./test-via-pipeline.sh /path/to/parameters.json
```

## Pipeline

This test is also included in the pipeline. It is in the 3rd stage of `Pipeline/azure-pipelines.yaml`