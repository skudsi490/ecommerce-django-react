from selenium import webdriver
import pytest

@pytest.fixture
def browser():
    driver = webdriver.Chrome()
    yield driver
    driver.quit()

def test_homepage(browser):
    browser.get('http://localhost:80')
    assert 'Ecommerce' in browser.title
