import setuptools

with open("README.md", "r") as fh:
    long_description = fh.read()

with open('requirements.txt') as f:
    requirements = f.read().splitlines()

setuptools.setup(
    name="PyViewer",
    version="0.0.1",
    install_requires=requirements,
    author="Javier Felip Leon",
    author_email="javier.felip.leon@intel.com",
    description="Simple OpenGL viewer for python with a simple SceneGraph.",
    long_description=long_description,
    long_description_content_type="text/markdown",
    packages = ['PyViewer'],
    classifiers=[
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
    ],
)
