import os
import pycurl
from StringIO import StringIO


def curl(url, buff=None, userCert=None, userKey=None):
    c = pycurl.Curl()
    c.setopt(c.URL, url)
    c.setopt(c.SSL_VERIFYPEER, False)

    # try to fetch the user certificate and key from the environment 
    if 'X509_USER_CERT' in os.environ:
        c.setopt(c.SSLCERT, os.environ['X509_USER_CERT'])    
    if 'X509_USER_KEY' in os.environ:
        c.setopt(c.SSLKEY, os.environ['X509_USER_KEY'])
    # overwrite the user certificate and key from function parameters
    if userCert:
        c.setopt(c.SSLCERT, userCert)    
    if userKey:
        c.setopt(c.SSLKEY, userKey)
    
    if isinstance(buff, file):
        writeBuff = buff
    elif isinstance(buff, str):
        writeBuff = StrinIO(buff)
    else:
        writeBuff = SringIO()
    print("writeBuff type: %s" % type(writeBuff))
    c.setopt(c.WRITEDATA, writeBuff)   
    c.perform()
    httpCode = c.getinfo(c.HTTP_CODE)
    effURL = c.getinfo(c.EFFECTIVE_URL)
    c.close()
    print("URL: %s HTTP CODE: %s" % (effURL, httpCode))
    return writeBuff
