- Implement the logic to send request to A1111 API. To achieve this, we need to:
  - Some additional UI adjustments:
    - Read checkpoint models from $A1111_directory/models/Stable-diffusion/
    - Add Lora section right under Model Selection, And they should be grouped in one visual container.
      - Read lora models from $A1111_directory/models/Lora/
      - Multiple Lora can be added for one generation at the same time. When one lora is added, we should append <lora:lora_file_name:1> to positive prompt. 
    - Quality setting should contain the following attributes:
      - Sampler, Scheduler, Steps, CFG Scale
  - You will send a http post request to /sdapi/v1/txt2img, with a json payload. It would return a json response where you can get image_data with the following logic (python equivalent):
    ``` 
    response = requests.post(url='http://127.0.0.1:7860/sdapi/v1/txt2img', json=payload)

    # Decode the Base64 image
    image = response.json()['images'][0]
    image_data = base64.b64decode(image)
    ```
  - I also provided a sample request.json under (./a1111_reference_request.json), in which:
    - You should swap: 
      - Dynamic Thresholding (CFG Scale Fix): 2nd value in the array should match our CFG
      - Sampler: contains 3 args: steps, sampler, and scheduler
      - Seed: 1st value should match with our seed
      - cfg_scale: should match our CFG
      - height: should match with our height
      - negative_prompt: should match with our negative prompt
      - prompt: should match with our positive prompt
      - sampler_name:should match with our sampler
      - scheduler: should match with scheduler
      - seed: should match with seed
      - steps: should match with steps
      - width: should match with width
    - If you find other fields that you are not sure if you should swap, let me know.
    - You should also maintain a request template for you to swap values on. This would also help devs to switch default values later on.
  - To preview the image, in python we do the following, you should implement a flutter equivalent. 
    ```
    from io import BytesIO
    from PIL import Image

    def preview_image(image_data):
        img = Image.open(BytesIO(image_data))
        return img
    ```