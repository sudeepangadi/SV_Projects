//`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/01/2023 09:39:09 PM
// Design Name: 
// Module Name: spi
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module spi(input clk,newd, rst,
           input [11:0] din,
           output reg sclk, cs, mosi
    );
    
    parameter IDLE = 2'b00;
    parameter ENABLE = 2'b01;
    parameter SEND = 2'b10;
    parameter COMP = 2'b11;
    
    reg[1:0] state = IDLE;
    
    integer count = 0;
    integer countc = 0;
    
    always @(posedge clk)
    begin
        if(rst==1'b1)
        begin
            countc <=0;
            sclk <= 1'b0;
        end
        else
        begin
            if(countc < 50)
                countc <= countc + 1;
            else
                begin
                    countc <= 0;
                    sclk = ~sclk;
                end    
        end
    end
    
    
    reg [11:0] temp;
    
    always @(posedge clk)
    begin
        if(rst==1'b1)
        begin
            cs <= 1'b1;
            mosi <= 1'b0;
        end
        else
        begin
            case(state)
                IDLE : begin
                           if(newd==1'd1)
                           begin
                                state <= SEND;
                                temp <= din;
                                cs <= 1'b0;
                           end
                           else
                            begin
                                state <= IDLE;
                                temp <= 8'h00;
                           end 
                       end
               SEND : begin
                           if(count <= 11)
                           begin
                                mosi <= temp[count];
                                count <= count + 1;
                           end
                           else
                           begin
                                count <= 0;
                                state <= IDLE;
                                cs <= 1'b1;
                                mosi <= 1'b0;
                           end 
                           
                      end  
                default : state <= IDLE;            
            endcase           
        end
    end
endmodule
