from selenium import webdriver
from selenium.webdriver.support import expected_conditions
from selenium.webdriver.support.ui import WebDriverWait, Select
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.common.keys import Keys
from selenium.webdriver.chrome.service import Service as ChromiumService
from webdriver_manager.chrome import ChromeDriverManager
from webdriver_manager.core.utils import ChromeType
from csv import DictWriter
import sys
import time

website_url = "https://www.pcrisk.com/search?"
count = 0
field_names = ['EXTENSION', 'RANSOMEWARE_NAME', 'LINK_URL']

options = webdriver.ChromeOptions()
options.add_argument("--headless")
options.add_argument('--no-sandbox')
browser = webdriver.Chrome(service=ChromiumService(ChromeDriverManager(chrome_type=ChromeType.CHROMIUM).install()), options=options)
browser.get(website_url)
timeout_secs: int = 20
waiting = WebDriverWait(browser, timeout_secs)	

with open("list.txt", "r", encoding="utf8") as file:
    lines = [line.strip() for line in file.readlines()]
    for line in lines:
        count += 1
        try:
            waiting.until(EC.presence_of_element_located((By.XPATH, '/html/body/div/div[1]/div[1]/div[1]/main/form/table[1]/tbody/tr[1]/td[2]/input')))
            browser.find_element("xpath", '/html/body/div/div[1]/div[1]/div[1]/main/form/table[1]/tbody/tr[1]/td[2]/input').send_keys(line)
            waiting.until(EC.presence_of_element_located((By.XPATH, '/html/body/div/div[1]/div[1]/div[1]/main/form/table[1]/tbody/tr[1]/td[3]/button')))
            browser.find_element("xpath", '/html/body/div/div[1]/div[1]/div[1]/main/form/table[1]/tbody/tr[1]/td[3]/button').click()
            waiting.until(EC.presence_of_element_located((By.XPATH, '/html/body/div/div[1]/div[1]/div[1]/main/form/table[1]/tbody/tr[1]/td[2]/input')))
            browser.find_element("xpath", '/html/body/div/div[1]/div[1]/div[1]/main/form/table[1]/tbody/tr[1]/td[2]/input').clear()
            waiting.until(EC.presence_of_element_located((By.XPATH, '/html/body/div/div[1]/div[1]/div[1]/main/form/table[2]/tbody/tr[2]/td')))
            not_found = browser.find_element("xpath", '/html/body/div/div[1]/div[1]/div[1]/main/form/table[2]/tbody/tr[2]/td')

            if not_found.text == "Total: 0 results found.":
                dict = {'EXTENSION': line, 'RANSOMEWARE_NAME': "N/A", 'LINK_URL': "N/A"} 

                with open('ExtensionWithRansomName.csv', 'a', newline='', encoding='utf-8') as f_object:
                    dictwriter_object = DictWriter(f_object, fieldnames=field_names)
                    #dictwriter_object.writeheader()
                    dictwriter_object.writerow(dict)
                    f_object.close()
            else:
                waiting.until(EC.presence_of_element_located((By.XPATH, '/html/body/div/div[1]/div[1]/div[1]/main/table/tbody/tr[1]/td/fieldset/div[1]/a/strong')))
                rsw_group = browser.find_element("xpath", '/html/body/div/div[1]/div[1]/div[1]/main/table/tbody/tr[1]/td/fieldset/div[1]/a/strong')
                waiting.until(EC.presence_of_element_located((By.XPATH, '/html/body/div/div[1]/div[1]/div[1]/main/table/tbody/tr[1]/td/fieldset/div[1]/a')))
                rsw_group_link = browser.find_element("xpath", '/html/body/div/div[1]/div[1]/div[1]/main/table/tbody/tr[1]/td/fieldset/div[1]/a').get_attribute('href')
                dict = {'EXTENSION': line, 'RANSOMEWARE_NAME': rsw_group.text, 'LINK_URL': rsw_group_link} 

                with open('ExtensionWithRansomName.csv', 'a', newline='', encoding='utf-8') as f_object:
                    dictwriter_object = DictWriter(f_object, fieldnames=field_names)
                    #dictwriter_object.writeheader()
                    dictwriter_object.writerow(dict)
                    f_object.close()

            print(f"Currently at: {count}", file=sys.stderr)
            time.sleep(10)
        except Exception as error:
            print(error, file=sys.stderr)
