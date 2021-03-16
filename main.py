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

    _artifacts = variables['artifacts']

    @macro
    @dedented
    def cfn_button(name, template, enabled=True):
        """
        create an cloudformation launch button
        """
        s3 = _artifacts['s3']

        if template.lower().startswith('http'):
            template_url = template
        else:
            s3['object'] = "/".join(
                filter(None, [s3.get('prefix'), 'latest', 'templates', template])
            )

            template_url = "https://{bucket}.s3.amazonaws.com/{object}".format(**s3)

        cfn_url = "".join([
            "https://console.aws.amazon.com/cloudformation/home?#/stacks/new?stackName=",
            name,
            "&templateURL=",
            template_url,
        ])
        
        img_src = "/" + "/".join(
            filter(None, [s3.get('prefix'), 'images/cloudformation-launch-stack.png'])
        )

        html = '<a href="{url}" target="_blank" class="launch-button"><i class="material-icons">play_arrow</i></a>'
        if not enabled:
            html = '<a class="launch-button launch-button-disabled"><i class="material-icons">play_arrow</i></a>'

        return html.format(name=name, img=img_src, url=cfn_url)
    
    @macro
    @dedented
    def download_button(path, icon="cloud_download"):
        """
        create a download button
        """
        repo_url = variables['repo_url']
        s3 = _artifacts['s3']
            
        if path.lower().startswith('http'):
            src_url = path
        else:
            # s3['object'] = "/".join(
            #     filter(None, [s3.get('prefix'), path])
            # )

            # src_url = "https://s3.amazonaws.com/{bucket}/{object}".format(**s3)
            if repo_url.endswith("/"):
                repo_url = repo_url[:-1]
            
            if path.startswith("/"):
                path = path[1:]
            
            src_url = f"{repo_url}/blob/master/src/{path}"
        
        return """
        <a href="{url}" target="_blank"><i class="material-icons">{icon}</i></a>
        """.format(icon=icon, url=src_url)
    
    @macro
    @dedented
    def cfn_stack_row(name, stack_name, template, description, enable_cfn_button=True):
        if template.lower().startswith('http'):
            stack_url = template
        else:
            stack_url = "templates/" + template

        return """
        | {name} | {description} | {download_button} | {cfn_button} |
        """.format(
            name=name,
            stack_name=stack_name,
            download_button=download_button(stack_url),
            cfn_button=cfn_button(stack_name, template, enabled=enable_cfn_button),
            description=description
        )