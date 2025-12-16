import asyncio
from playwright.async_api import async_playwright, Page, expect, Error
import time
import re
import boto3
import datetime
from tenacity import retry, stop_after_attempt
import numpy as np
from deltalake import DeltaTable, write_deltalake

lambda_client = boto3.client('lambda', region_name='us-east-1')
scheduler_client = boto3.client('scheduler', region_name='us-east-1')
lambda_function_arn = 'arn:aws:lambda:us-east-1:247376099496:function:veritec_email'

rule_name = "veritec-email-rule"

#%%
async def schedule_veritec_email_read(delay, workflow):
    schedule_time = datetime.datetime.utcnow() + datetime.timedelta(minutes=delay)
    schedule_expression = f"at({schedule_time.strftime('%Y-%m-%dT%H:%M:%S')})"
    
    custom_data = {
        "workflow": workflow
    }
    
    input_payload = json.dumps(custom_data)
    
    try:
        scheduler_client.delete_schedule(
            Name=rule_name
        )
    except ClientError as err:
        if err.response["Error"]["Code"] == "ResourceNotFoundException":
            logger.error(
                "Failed to delete schedule with ID '%s' because the resource was not found: %s",
                rule_name,
                err.response["Error"]["Message"],
            )
        else:
            logger.error(
                "Error deleting schedule: %s", err.response["Error"]["Message"]
            )
            raise

    response = scheduler_client.create_schedule(
        Name=rule_name,
        ScheduleExpression=schedule_expression,
        FlexibleTimeWindow={
            'MaximumWindowInMinutes': 5,
            'Mode': 'FLEXIBLE',
            
        },
        Target={
            'Arn': lambda_function_arn,
            'RoleArn': 'arn:aws:iam::247376099496:role/eventbridge_lambda_scheduler',
            'Input': input_payload,
            },

    )

    return response
#%%

async def get_store_list(page, include_list, exclude_list):
    """
    Clicks checkboxes in table rows that contain specific data.

    Args:
        page: The Playwright page object.
        table_selector: CSS selector for the table.
        data_to_match: The text content to look for in a row's data cells.
    """
    # table_rows = page.locator(f"{table_selector} tr")
    time.sleep(1)
    # await expect(page.get_by_role("grid").nth(1)).to_be_visible()
    table = page.get_by_role("grid").nth(1)
    table_rows = table.get_by_role("row")

    print(await table_rows.count())

    data_list = []

    # Iterate through each row
    for i in range(await table_rows.count()):
        row = table_rows.nth(i)
        print(row)
        # Check if the row contains the desired data
        or_seperator = "|"
        exclude_list_string = or_seperator.join(exclude_list)
        await page.wait_for_load_state("networkidle")

        if await row.locator("td", has_text=re.compile(exclude_list_string)).count() == 0:
            # Locate and check the checkbox within this specific row
            await page.wait_for_load_state("networkidle")

            row_dict = {
                'company': await row.locator('span[ng-bind="dataItem.strCompany"]').text_content(),
                'source': await row.locator('span[ng-bind="dataItem.strSource"]').text_content(),
                'address': await row.locator('span[ng-bind="dataItem.strAddress"]').text_content(),
                'city': await row.locator('span[ng-bind="dataItem.strcity"]').text_content(),
                'zipcode': await row.locator('span[ng-bind="dataItem.strZipcode"]').text_content(),
                'state': await row.locator('span[ng-bind="dataItem.strState"]').text_content(),
                'previous_store_name': await row.locator('span[ng-bind="dataItem.strPreviousStoreName"]').text_content(),
                'data_update_date': await row.get_by_title(" ").inner_text()
            }

            print(row_dict)

            data_list.append(row_dict)

            print(data_list)

    df = pd.DataFrame(data_list)

    if include_list:

        df = df.query(f'company in {str(include_list)} ')

    return df


# %%

async def click_checkboxes_in_table_rows(page, store_list, exclude_list):
    """
    Clicks checkboxes in table rows that contain specific data.

    Args:
        page: The Playwright page object.
        table_selector: CSS selector for the table.
        data_to_match: The text content to look for in a row's data cells.
    """
    # table_rows = page.locator(f"{table_selector} tr")
    time.sleep(1)
    # await expect(page.get_by_role("grid").nth(1)).to_be_visible()
    table = page.get_by_role("grid").nth(1)
    table_rows = table.get_by_role("row")

    print(await table_rows.count())

    # Iterate through each row
    for i in range(await table_rows.count()):
        row = table_rows.nth(i)
        print(row)
        # Check if the row contains the desired data
        or_seperator = "|"
        store_list_string = or_seperator.join(store_list)
        exclude_list_string = or_seperator.join(exclude_list)
        await page.wait_for_load_state("networkidle")
        print("check td visibility")
        # await expect(row.locator("td"), has_text=re.compile(store_list_string)).to_be_visible(timeout = 50000)
        print("count list")
        if await row.locator("td", has_text=re.compile(store_list_string)).count() > 0:
            await page.wait_for_load_state("networkidle")
            print("count exclude list")
            if await row.locator("td", has_text=re.compile(exclude_list_string)).count() == 0:
                # Locate and check the checkbox within this specific row
                await page.wait_for_load_state("networkidle")
                print("checkbox visibility check")
                # await expect(row.locator("input[type='checkbox']").first).to_be_visible()
                print("checkbox check")
                checkbox = row.locator("input[type='checkbox']")

                if await checkbox.is_visible():
                    await checkbox.check()
                    print(f"Checkbox checked in row containing '{store_list}'")
                else:
                    print(f"Checkbox not visible in row containing '{store_list}'")

# %%

async def unclick_checkboxes_in_table_rows(page, store_list, exclude_list):
    """
    Clicks checkboxes in table rows that contain specific data.

    Args:
        page: The Playwright page object.
        table_selector: CSS selector for the table.
        data_to_match: The text content to look for in a row's data cells.
    """
    # table_rows = page.locator(f"{table_selector} tr")
    time.sleep(1)
    # await expect(page.get_by_role("grid").nth(1)).to_be_visible()
    table = page.get_by_role("grid").nth(1)
    table_rows = table.get_by_role("row")

    print(await table_rows.count())

    # Iterate through each row
    for i in range(await table_rows.count()):
        row = table_rows.nth(i)
        print(row)
        # Check if the row contains the desired data
        or_seperator = "|"
        store_list_string = or_seperator.join(store_list)
        exclude_list_string = or_seperator.join(exclude_list)
        await page.wait_for_load_state("networkidle")
        print("check td visibility")
        # await expect(row.locator("td"), has_text=re.compile(store_list_string)).to_be_visible(timeout = 50000)
        print("count list")
        if await row.locator("td", has_text=re.compile(store_list_string)).count() > 0:
            await page.wait_for_load_state("networkidle")
            print("count exclude list")
            if await row.locator("td", has_text=re.compile(exclude_list_string)).count() == 0:
                # Locate and check the checkbox within this specific row
                await page.wait_for_load_state("networkidle")
                print("checkbox visibility check")
                # await expect(row.locator("input[type='checkbox']").first).to_be_visible()
                print("checkbox check")
                checkbox = row.locator("input[type='checkbox']")

                if await checkbox.is_visible():
                    await checkbox.uncheck()
                    print(f"Checkbox unchecked in row containing '{store_list}'")
                else:
                    print(f"Checkbox not visible in row containing '{store_list}'")


# %%
@retry(stop=stop_after_attempt(3))
async def veritec_login(pw) -> Page:
    try:
        browser = await pw.chromium.launch(headless=True, downloads_path=".")
        context = await browser.new_context(accept_downloads=True,
                                            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36")
        page = await context.new_page()

        url = 'https://rmsprod2.veritecrms.com/#/'

        await page.goto(url)

        # pg = await page.content()

        await page.get_by_placeholder('Corporate Code').fill('Trunk');

        await page.get_by_placeholder('Username').first.fill('SSquires');

        await page.get_by_placeholder('Password').first.fill('Shane123');

        await page.locator("#loginvbutton").click()

        await page.wait_for_load_state("networkidle")

        time.sleep(1)

        await expect(page.get_by_title("Configure")).to_be_visible()
        # await expect(page.get_by_title("Configure")).to_be_enabled()

        # time.sleep(3)

        await page.get_by_title("Configure").wait_for(state="visible", timeout=10000)
        await page.get_by_title("Configure").click(force=True)

        # Now you can interact with the element, which is no longer hidden.
        # await page.locator('[data-ng-transclude]').locator("#histcompsetid span").nth(1).click()
        await page.wait_for_load_state("networkidle")
        time.sleep(1)
        await expect(page.get_by_title("Historical Competition Set").nth(1)).to_be_visible()
        # await expect(page.get_by_title("Historical Competition Set").nth(1)).to_be_enabled()

        await page.get_by_title("Historical Competition Set").nth(1).wait_for(state="visible", timeout=10000)
        await page.get_by_title("Historical Competition Set").nth(1).click(force=True)

        await page.wait_for_load_state("networkidle")

        status = "Successfully Logged In!"

    except Error as e:
        print(e)

        status = "Failed to Login"

    return [page, status]

#%%

def upsert_vt_delta(table_path, df):
    delta_table = DeltaTable(table_path)

    (
        delta_table.merge(
            source=df,
            predicate='''
            s.company = t.company AND
            s.source = t.source AND
            s.address = t.address AND
            s.city = t.city AND
            s.state = t.state AND
            s.previous_store_name = t.previous_store_name AND
            s.data_update_date = t.data_update_date AND
            s.start_date = t.start_date AND
            s.frequency = t.frequency AND
            s.request_time = t.request_time AND
            s.status = t.status

            '''
                      ,
            source_alias="s",
            target_alias="t")
        .when_matched_update_all()
        .when_not_matched_insert_all().execute() \
        )
# %%
async def get_veritec_street_rate(store_list, exclude_list, coords, radius, start_date, chunk_size, frequency, workflow):
    async with async_playwright() as pw:

        login_output = await veritec_login(pw)

        page = login_output[0]

        status = login_output[1]
        time.sleep(1)

        try:
            for row_tuple in coords.itertuples():
                print(f"Index: {row_tuple.Index}, Latitude: {row_tuple.Latitude}, Longitude: {row_tuple.Longitude}")
                latitude = str(row_tuple.Latitude)
                longitude = str(row_tuple.Longitude)
                await expect(page.get_by_role("spinbutton").first).to_be_visible()
                await page.get_by_role("spinbutton").first.click()
                await page.wait_for_load_state("networkidle")
                time.sleep(1)
                await page.get_by_role("spinbutton").first.wait_for(state="visible", timeout=10000)
                await page.get_by_role("spinbutton").first.fill(latitude)

                await expect(page.get_by_role("spinbutton").nth(1)).to_be_visible()
                await page.get_by_role("spinbutton").nth(1).click()
                time.sleep(1)
                await page.get_by_role("spinbutton").nth(1).wait_for(state="visible", timeout=10000)
                await page.get_by_role("spinbutton").nth(1).fill(longitude)

                await page.wait_for_load_state("networkidle")
                time.sleep(1)
                await page.locator("input[type='number']").first.fill(radius, force=True)

                await page.wait_for_load_state("networkidle")
                time.sleep(1)
                await expect(page.locator("#daysDataDropDown")).to_be_visible()
                await page.locator("#daysDataDropDown").select_option(value="5")

                await page.wait_for_load_state("networkidle")
                time.sleep(1)

                store_df = await get_store_list(page, store_list, exclude_list)

                store_df = store_df.assign(
                    start_date=start_date,
                    frequency = frequency,
                    request_time = datetime.datetime.now(),
                )

                num_chunk = store_df.shape[0] // chunk_size

                df_chunks = np.array_split(store_df, num_chunk)

                for df in df_chunks:

                    try:
                        await click_checkboxes_in_table_rows(page, df.address.tolist(), exclude_list)

                        await page.get_by_title("Request Hist Comps").click()

                        # await expect(page.get_by_role('listbox')).to_be_visible()
                        time.sleep(1)
                        await page.get_by_role('listbox').wait_for(state="visible", timeout=10000)

                        await page.get_by_role('listbox').click()

                        await page.locator("#frequency").evaluate("el => el.style.display = 'block'")

                        await page.locator("#frequency").select_option(value=frequency)

                        await page.get_by_role('listbox').first.click()

                        await page.locator('input[data-role="datepicker"]').fill(start_date)

                        await page.get_by_role("button", name="Save").click()

                        await page.get_by_role("button", name="Ok").click()

                        time.sleep(1)

                        df['status'] = "Success"
                        
                        if workflow == "baranof":
                          table_path = "s3://baranof-veritec/baranof-street-rate/bronze/requests"
                        elif workflow == "adhoc":
                          table_path = "s3://baranof-veritec/street-rate/bronze/requests"

                        upsert_vt_delta( table_path, df)

                        await unclick_checkboxes_in_table_rows(page, df.address.tolist(), exclude_list)

                    except Error as e:
                        print(e)

                        df['status'] = "Failed"

                await page.close()

                await schedule_veritec_email_read(20, workflow)

                status_read = "Successfully Scheduled Email Read!"

        except Error as e:
            print(e)

            status_read = "Failed to Schedule Email Read"

        return [status, status_read]



# %%

def veritec_street_rate_runner(store_list, exclude_list, coords, radius, start_date, chunck_size, frequency, workflow):
    statuses = asyncio.run(get_veritec_street_rate(store_list, exclude_list, coords, radius, start_date, chunck_size, frequency, workflow))
    return statuses




