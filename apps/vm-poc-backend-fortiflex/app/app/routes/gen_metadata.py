# generate_metadata.py
from onelogin.saml2.settings import OneLogin_Saml2_Settings

settings = OneLogin_Saml2_Settings(settings=None, custom_base_path="saml")
print(settings.get_sp_metadata())