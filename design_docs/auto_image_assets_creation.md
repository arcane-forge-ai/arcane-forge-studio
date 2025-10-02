# Auto Image Assets Creation

## Summary
- Automatically parse a doc from either knowledge base or upload and create art assets for user.
- Apporach:
  - Add another button on the top of image_overview_screen called `Create Assets from Doc`, which would push a dialogue or page
  - User would either:
    - select a doc from knowledge base
    - or upload a doc from local
  - Read the file content, and call the newly created `/api/v1/{project_id}/assets/extract` endpoint, this would return a list of assets
  - Show the result to user, with columns of name, descriptions, and metadata (all other metadata returned from the API)
  - User would be able to edit the name, descriptions and metadata of each row
  - User select the assets they want to create (by default should select all)
    - We should provide `Select All` and `UnSelect All` buttons
  - User click `Create Assets` button, and the software would call the newly created `/{project_id}/assets/batch-create`
    - If success, then go back to image_overview_screen.
    - If fail, notify user failure and should allow user to try again.