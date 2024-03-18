# RoundedRectangle-Love
LÖVE example of drawing an antialiased round-corner rectangle using a pixel shader.  
The rectangle is a quad mesh, and the round corners are produced by setting the alpha value of pixels that fall outside of the corner region. The optional border (internal to the rectangle area) is done in a similar way.

For simplicity, the corner radius and border thickness are set as a uniform, but ideally you'd store these as vertex attributes, so a single mesh object could hold many different rectangles with unique settings.

![roundedRectanglePreview](https://github.com/RNavega/RoundedRectangle-Love/assets/28221053/645b762a-e0b2-4b6a-a83a-eb06c6a1df9c)
