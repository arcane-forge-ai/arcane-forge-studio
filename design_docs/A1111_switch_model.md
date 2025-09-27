# A1111 Model(Checkpoint) Switch

## Summary
- Our previous workflow has a problem:
  - There is no checkpoint related param in the request template a1111_request.json
  - Therefore all generations would use the previous loaded checkpoint
- To switch checkpoint
  - call `POST /sdapi/v1/options` with a request body:
  ```json
  {
    "sd_model_checkpoint": "$model_title"
    }
  ```
- As a bonus finding, I also found out the best way of getting list of available checkpoints for A1111 -- call `GET /sdapi/v1/sd-models`, it will return us a response like the following:
```
[
  {
    "title": "abstractAnim_v1.ckpt",
    "model_name": "abstractAnim_v1",
    "hash": null,
    "sha256": null,
    "filename": "H:\\sd-webui-aki-v4.8\\models\\Stable-diffusion\\abstractAnim_v1.ckpt",
    "config": null
  },
  {
    "title": "anyloraCheckpoint_bakedvaeBlessedFp16.safetensors [ef49fbb25f]",
    "model_name": "anyloraCheckpoint_bakedvaeBlessedFp16",
    "hash": "ef49fbb25f",
    "sha256": "ef49fbb25fa908bb54ded95abf81ef4b0e21fa0a8de56c40c3d62e768ef7e49a",
    "filename": "H:\\sd-webui-aki-v4.8\\models\\Stable-diffusion\\anyloraCheckpoint_bakedvaeBlessedFp16.safetensors",
    "config": null
  },
  ...
]
```
  - we should use this list to build our checkpoint dropdown. And use `model_name` as the display value
- Similarly, the best way of getting list of Lora is through `GET /sdapi/v1/loras`. There are quite a lot info in the response, but for now let's only have the following defined:
```json
{
    "name": "$name_of_lora",
    "alias": "$alias_of_lora",
    "path": "$path_of_lora",
    "metadata": "$an_object_of_metadata"
}
```
  - we should use this list to build our lora dropdown. And use `name` as the value in both `dropdown` and prompt injection.
- so the new corrected workflow should be:
  1. When user submit a generation request, first call `GET /sdapi/v1/options` and check if `sd_model_checkpoint` equals to the current selected checkpoint's **title** value (not the *model_name*!)
  2. if it doesn't match, then we call `POST /sdapi/v1/options` and update the `sd_model_checkpoint` with the selected checkpoint's **title**
  3. proceed with the previous image generation request