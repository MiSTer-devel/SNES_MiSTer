module rgb2ypbpr (
	input [5:0]     red,
	input [5:0]     green,
	input [5:0]     blue,

	output [5:0]    y,
	output [5:0]    pb,
	output [5:0]    pr
);	

// http://marsee101.blog.fc2.com/blog-entry-2311.html
// Y = 0.257R + 0.504G + 0.098B + 16
// Cb = -0.148R - 0.291G + 0.439B + 128
// Cr = 0.439R - 0.368G - 0.071B + 128

wire [18:0]  y_lshift8 = 19'd04096 + ({red, 8'd0} + {red, 3'd0}) + ({green, 9'd0} + {green, 2'd0}) + ({blue, 6'd0} + {blue, 5'd0} + {blue, 2'd0});
wire [18:0] cb_lshift8 = 19'd32768 - ({red, 7'd0} + {red, 4'd0} + {red, 3'd0}) - ({green, 8'd0} + {green, 5'd0} + {green, 3'd0}) + ({blue, 8'd0} + {blue, 7'd0} + {blue, 6'd0});
wire [18:0] cr_lshift8 = 19'd32768 + ({red, 8'd0} + {red, 7'd0} + {red, 6'd0}) - ({green, 8'd0} + {green, 6'd0} + {green, 5'd0} + {green, 4'd0} + {green, 3'd0}) - ({blue, 6'd0} + {blue , 3'd0});

always @(*) begin
	if (y_lshift8[18] == 1'b1 || y_lshift8[17:8]<16)
		y <= 6'd4;
	else if (y_lshift8[17:8] > 235)
		y <= 6'd58;
	else
		y <=  y_lshift8[15:10];

	if (cb_lshift8[18] == 1'b1 || cb_lshift8[17:8]<16)
		pb <= 6'd4;
	else if (cb_lshift8[17:8] > 240)
		pb <= 6'd60;
	else
		pb <=  cb_lshift8[15:10];

	if (cr_lshift8[18] == 1'b1 || cr_lshift8[17:8]<16)
		pr <= 6'd4;
	else if (cr_lshift8[17:8] > 240)
		pr <= 6'd60;
	else
		pr <=  cr_lshift8[15:10];
end

endmodule
