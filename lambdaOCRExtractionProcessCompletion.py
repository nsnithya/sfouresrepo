import json
import boto3
import urllib.parse
import time
import os

# Initialize boto3 clients for Textract and S3
textract = boto3.client('textract')
s3 = boto3.client('s3')
sns_client = boto3.client('sns')



def lambda_handler(event, context):
    try:
        # Loop through each record (message) in the SQS event
        for record in event['Records']:
            # Parse the message body and extract the job ID
            message_body = json.loads(record['body'])
            #print(f"Message Body: {message_body}")
            textract_message = json.loads(message_body['Message'])
            job_id = textract_message['JobId']
            status = textract_message['Status']

            s3init_ObjectName = textract_message['DocumentLocation']['S3ObjectName']
            foldername, filename = s3init_ObjectName.split('/')
            #print(f"Textract job ID: {job_id} Status: {status} filename: {filename}")
            
            filename_without_extension = os.path.splitext(os.path.basename(filename))[0]
            timestr = time.strftime("%Y%m%d-%H%M%S")
            #To save OCR extraction Json
            outputfilename = (f"{filename_without_extension}_{timestr}_{job_id}")
            
            #To save clean simple text file for AWS comprehend
            cleanpdf_prefix = os.getenv('cleanpdfprefix')
            clean_outputfilename = (f"{filename_without_extension}_{cleanpdf_prefix}_{timestr}_{job_id}") 
            
            # Check if the job completed successfully
            if status == "SUCCEEDED":
                # Call Textract to get the job results
                all_results = get_all_results(job_id)
                #response = merge_results(all_results)
                result_json = merge_results(all_results)
                # Call Textract to get the job results
                #response = textract.get_document_analysis(
                #    JobId=job_id
                #) 

                # Define the S3 bucket and object key for storing results
                output_bucket = textract_message['DocumentLocation']['S3Bucket']
                ocrresults_folder = os.getenv('ocrresultsfolder')
                output_key = f'{ocrresults_folder}{outputfilename}.json'

              
                # Convert the response to JSON format
                #result_json = json.dumps(response)
                #print(f"Result Json: {result_json}")
                # Upload the results to S3
                s3.put_object(
                    Bucket=output_bucket,
                    Key=output_key,
                    Body=result_json
                )

                print(f"Textract results for job {job_id} stored in S3 bucket '{output_bucket}' with key '{output_key}'")
                
                print(f"result_json: {result_json}")
                formatted_text = extract_text_from_textract(json.loads(result_json))
                 
                #print(f"formatted_text: {formatted_text}") 
                # Convert to JSON string to simple text for AWS Comprehend
                comprehend_input = json.dumps({"text": formatted_text})
                
                #Check if saveCleanpdfs3_featureflag enabled then only save to S3 folder
                savecleanpdfs3_featureflag = os.getenv('savecleanpdfs3')
                if savecleanpdfs3_featureflag:
                    cleanpdf_output_key = f'{ocrresults_folder}{clean_outputfilename}.txt'
                    #print(f'{cleanpdf_output_key}')
                    # Upload the results to S3
                    s3.put_object(
                        Bucket=output_bucket,
                        Key=cleanpdf_output_key,
                        Body=comprehend_input
                    )
                    
                #print(comprehend_input)
                
                
                #Once processing is complete, publish to SNS
                topic_arn = os.getenv('topicarn')
                custom_payload = {
                            "bucket_name": output_bucket,
                            "job_id": job_id,
                            "input_file_key": s3init_ObjectName,
                            "file_name": filename,
                            "output_file": output_key
                        }
                #Construct the message for different protocol
                message_body = {
                    "default": json.dumps(custom_payload)
                }        
                print(f"SNS Message for Message: {message_body} ")
                
                response = sns_client.publish(
                TopicArn=topic_arn,
                MessageStructure = 'json',
                Message= json.dumps(message_body),
                Subject="Lambda Process Complete"
                )
    
                print(f"SNS Message for Job {job_id} with Message: {message_body} ")

                
            else:
                print(f"Textract job {job_id} did not succeed. Status: {status}")
                
        return {
            'statusCode': 200,
            'body': json.dumps('Processing completed successfully')
        }

    except Exception as e:
        print(f"Error processing Textract job result: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps(f"Error processing Textract job result: {e}")
        }


def get_all_results(job_id):
    all_results = []
    response = textract.get_document_analysis(JobId=job_id)
    all_results.extend(response['Blocks'])

    while 'NextToken' in response:
        next_token = response['NextToken']
        response = textract.get_document_analysis(JobId=job_id, NextToken=next_token)
        all_results.extend(response['Blocks'])
    
    return all_results

def merge_results(all_results):
    return json.dumps({'Blocks': all_results})

def extract_text_from_textract(textract_json):
   
    blocks = textract_json.get('Blocks',[])
    
    page_text = {}
    
    for block in blocks:
        block_type = block.get('BlockType')
        
        # Initialize page entry if not already present
        page_number = block.get('Page', 1)
        if page_number not in page_text:
            page_text[page_number] = []

        if block_type == 'LINE':
            # Extract text from LINE blocks
            page_text[page_number].append(block.get('Text', ''))

         # Handle TABLE blocks
        elif block_type == 'TABLE':
            relationships = block.get('Relationships', [])
            if isinstance(relationships, list):  # Ensure Relationships is a list
                for relationship in relationships:
                    if relationship.get('Type') == 'CHILD' and isinstance(relationship.get('Ids', []), list):
                        for child_id in relationship['Ids']:
                            # Find the child block (cell) by ID
                            cell_block = next((blk for blk in textract_json['Blocks'] if blk.get('Id') == child_id), None)
                            if cell_block and cell_block.get('BlockType') == 'CELL':
                                # Ensure Relationships is a list before accessing
                                if isinstance(cell_block.get('Relationships', []), list):
                                    row_text = ' '.join(
                                        child_block.get('Text', '') 
                                        for child_block in textract_json['Blocks'] 
                                        if child_block.get('Id') in cell_block.get('Relationships', [])
                                    )
                                    page_text[page_number].append(row_text)

                           
                        
        elif block_type == 'KEY_VALUE_SET':
            # Extract text from KEY_VALUE_SET blocks (forms)
            key_text = value_text = ''
            for entity in block.get('EntityTypes', []):
                if entity == 'KEY':
                    key_text = block.get('Text')
                elif entity == 'VALUE':
                    value_text = block.get('Text')
            if key_text or value_text:
                page_text[page_number].append(f"'{key_text}: {value_text}'")

    
    # Combine all text for each page
    combined_text = {}
    for page, texts in page_text.items():
        combined_text[page] = '\n'.join(texts)
    
    return combined_text


# Function to process Textract response and extract forms, tables, and raw text
def process_textract_response(response):
    blocks = response['Blocks']
    
    forms = []
    tables = []
    raw_text = ""
    
    # Dictionaries to store key-value pairs (for forms)
    key_map = {}
    value_map = {}
    block_map = {}
    
    # Set to track block ids already used in forms and tables
    used_block_ids = set()

    # Iterate through blocks and classify them
    for block in blocks:
        block_id = block['Id']
        block_map[block_id] = block

        # Extract raw text from LINE blocks (initially all text)
        if block['BlockType'] == 'LINE':
            if block_id not in used_block_ids:
                raw_text += block['Text'] + ' '

        # Extract forms by identifying KEY_VALUE_SET blocks
        if block['BlockType'] == 'KEY_VALUE_SET':
            if 'KEY' in block['EntityTypes']:
                key_map[block_id] = block
            elif 'VALUE' in block['EntityTypes']:
                value_map[block_id] = block

        # Extract tables by identifying TABLE and CELL blocks
        elif block['BlockType'] == 'TABLE':
            table = parse_table(block, blocks, used_block_ids)
            tables.append(table)

    # Link key-value pairs together for structured forms
    forms = extract_forms(key_map, value_map, block_map, used_block_ids)

    # Return forms, tables, and raw text that excludes forms and tables
    return forms, tables, raw_text.strip()

# Function to extract forms (key-value pairs)
def extract_forms(key_map, value_map, block_map, used_block_ids):
    forms = []
    
    for key_block_id, key_block in key_map.items():
        value_block_id = get_value_block_id(key_block)
        key_text = extract_text(key_block, block_map, used_block_ids)
        value_text = extract_text(value_map[value_block_id], block_map, used_block_ids) if value_block_id else ''
        
        if key_text and value_text:
            forms.append({key_text: value_text})
    
    return forms

# Get the value block ID associated with a key block
def get_value_block_id(key_block):
    for relationship in key_block.get('Relationships', []):
        if relationship['Type'] == 'VALUE':
            return relationship['Ids'][0]
    return None

# Extract text from a block (only if it's a WORD block)
def extract_text(block, block_map, used_block_ids):
    text = ''
    if 'Relationships' in block:
        for relationship in block['Relationships']:
            if relationship['Type'] == 'CHILD':
                for child_id in relationship['Ids']:
                    word_block = block_map.get(child_id)
                    if word_block and word_block['BlockType'] == 'WORD':
                        text += word_block['Text'] + ' '
                        used_block_ids.add(child_id)  # Mark the word block as used
    return text.strip()


# Function to parse and structure tables
def parse_table(table_block, blocks, used_block_ids):
    table = []
    block_map = {block['Id']: block for block in blocks}
    
    # Get all CELL blocks related to the table
    cells = [block for block in blocks if block['BlockType'] == 'CELL' and 'ParentId' in block and block['ParentId'] == table_block['Id']]
    
    table_map = {}
    for cell in cells:
        row = cell['RowIndex']
        col = cell['ColumnIndex']
        text = extract_text(cell, block_map, used_block_ids)
        
        if row not in table_map:
            table_map[row] = {}
        table_map[row][col] = text
    
    # Convert the table_map to an ordered 2D array
    for row in sorted(table_map.keys()):
        table_row = []
        for col in sorted(table_map[row].keys()):
            table_row.append(table_map[row][col])
        table.append(table_row)
    
    return table