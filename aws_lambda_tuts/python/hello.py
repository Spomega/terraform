def lambda_handler(event, context):
    name = event.get('key1', 'World')
    message = f"Hello {name}!"
    return {
        'message' : message
    }