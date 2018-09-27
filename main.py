"""
defines macros for documents using mkdocs-macros-plugin
"""

from textwrap import dedent
from functools import wraps

def dedented(f):
    @wraps(f)
    def wrapper(*args, **kwargs):
        return dedent(f(*args, **kwargs).strip())
    return wrapper

def declare_variables(variables, macro):

    _variables = variables[variables['staging']]

    @macro
    @dedented
    def cfn_button(name, template):
        """
        create an cloudformation launch button
        """

        s3 = _variables['s3']
        s3['object'] = "/".join(
            filter(None, [s3.get('prefix'), 'template', template])
        )

        cfn_url = "".join([
            "https://console.aws.amazon.com/cloudformation/home?#/stacks/new?stackName=",
            name,
            "&templateURL=",
            "https://s3.amazonaws.com/{bucket}/{object}".format(**s3),
        ])

        return """
        [![cloudformation-launch-button](/images/cloudformation-launch-stack.png)]({url})
        """.format(url=cfn_url)
    
    @macro
    @dedented
    def download_button(path, icon="fa-download"):
        """
        create a download button
        """

        s3 = _variables['s3']
        s3['object'] = "/".join(
            filter(None, [s3.get('prefix'), path])
        )

        src_url = "https://s3.amazonaws.com/{bucket}/{object}".format(**s3)
        
        return """
        [:{icon}:]({url})
        """.format(icon=icon, url=src_url)