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
            filter(None, [s3.get('prefix'), 'templates', template])
        )

        cfn_url = "".join([
            "https://console.aws.amazon.com/cloudformation/home?#/stacks/new?stackName=",
            name,
            "&templateURL=",
            "https://s3.amazonaws.com/{bucket}/{object}".format(**s3),
        ])

        img_src = "/" + "/".join(
            filter(None, [s3.get('prefix'), 'images/cloudformation-launch-stack.png'])
        )

        return """
        <a href="{url}" target="_blank" class="launch-button"><i class="material-icons">play_arrow</i></a>
        """.format(name=name, img=img_src, url=cfn_url)
    
    @macro
    @dedented
    def download_button(path, icon="cloud_download"):
        """
        create a download button
        """

        s3 = _variables['s3']
        s3['object'] = "/".join(
            filter(None, [s3.get('prefix'), path])
        )

        src_url = "https://s3.amazonaws.com/{bucket}/{object}".format(**s3)
        
        return """
        <a href="{url}"><i class="material-icons">{icon}</i></a>
        """.format(icon=icon, url=src_url)
    
    @macro
    @dedented
    def cfn_stack_row(name, stack_name, template, description):
        return """
        | {name} | {description} | {download_button} | {cfn_button} |
        """.format(
            name=name,
            stack_name=stack_name,
            download_button=download_button("templates/" + template),
            cfn_button=cfn_button(stack_name, template),
            description=description
        )