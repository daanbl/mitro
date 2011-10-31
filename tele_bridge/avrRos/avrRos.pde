#include "WProgram.h"
#include <stdio.h>
#include "Ros.h"
#include "String.h"
#include "VelocityCommand.h"
#include "JointStates.h"
#include <Servo.h>

# define QPOS         0x08            //Query Position
# define QSPD         0x10            //Query Speed
# define CHFA         0x18            //Check for Arrival
# define TRVL         0x20            //Travel Number of Positions
# define CLRP         0x28            //Clear Position
# define SREV         0x30            //Set Orientation as Reversed
# define STXD         0x38            //Set TX Delay
# define SMAX         0x40            //Set Speed Maximum
# define SSRR         0x48            //Set Speed Ramp Rate
# define Left_Wheel   0x02            //Set address for left wheel
# define Right_Wheel  0x01            //Set address for right wheel
# define Both_Wheels  0x00            //Set address for both wheels
# define Relais              2              
# define EmergencyDetect     3

# define MAX_SPEED     30.0
# define DELAY_TIME    5

Publisher js_pub;

tele_msgs::VelocityCommand cmd_vel_msg;
tele_msgs::JointStates js_msg;

Servo M1Control;
Servo M2Control;

double M1previous_error = 0;
double M1integral = 0;
double M1Prevtime = 0;
double M1ActualSpeed = 0;
double M1SpeedSetpoint = 0;
double M1PulseLength = 1500;
double M2previous_error = 0;
double M2integral = 0;
double M2Prevtime = 0;
double M2ActualSpeed = 0;
double M2SpeedSetpoint = 0;
double M2PulseLength = 1500;

double  delayTime = 0;

// int last_vel_cmd_time = 0;

void set_vel(Msg *msg){
  M1SpeedSetpoint = min(max(cmd_vel_msg.velocity_right, - MAX_SPEED), MAX_SPEED);
  M2SpeedSetpoint = min(max(cmd_vel_msg.velocity_left, - MAX_SPEED), MAX_SPEED);

  //  char string[20];
  //  dtostrf(cmd_vel_msg.velocity_left, 1, 3, string);
  //  sprintf(response_msg.data.getRawString(), "hello %s", string);

  //  ros.publish(resp, &response_msg);

//  last_vel_cmd_time = millis();
}


// Since we are hooking into a standard arduino sketch, we must define our program in
// terms of the arduino setup and loop functions.

void setup(){

  // setup motors & relais
  pinMode(Relais, OUTPUT);
  digitalWrite(Relais, HIGH);
  pinMode(EmergencyDetect, INPUT);
  M1Control.attach(9);
  M2Control.attach(10);
  extern HardwareSerial Serial3; // initial Arduino Mega number 3 serial port, pins 14 and 15 on Mega board.
  Serial3.begin(19200);
  initMotors();
  digitalWrite(Relais, LOW);  

  // ROS
  ros.initCommunication();
  js_pub = ros.advertise("joint_states");
  ros.subscribe("cmd_vel", set_vel, &cmd_vel_msg);
  js_msg.position_right = 0;
  js_msg.position_left = 0;
  js_msg.velocity_right = 0;
  js_msg.velocity_left = 0;

  // last_vel_cmd_time = millis();

}

// ------------------------------------------------------------------------------------------



void initMotors()
{
  //Serial.println(" Initialising  the motors") ;
  //Set_Transmit_Delay(10);

  delay(10);
  Clear_Position(Left_Wheel);  // clear left wheel position  
  delay (10);
  Clear_Position(Right_Wheel);  // clear right wheel positions
  delay (10);
  Clear_Position(Both_Wheels);  // clear both wheel positions  (just to make sure)
  delay (10);
  Set_Speed_Ramp_Rate (Both_Wheels, 15);
  delay(10);
  Set_Speed_Maximum(Both_Wheels, 22);
  delay(10);   

  M1SpeedSetpoint = 0.0;
  M2SpeedSetpoint = 0.0;
}


void loop() {
  ros.spin();

  if (digitalRead(EmergencyDetect) == 0) { // || millis() - last_vel_cmd_time > 200 ) {
    M1Control.write(1500);
    M2Control.write(1500);
    M1PulseLength = 1500.0;
    M2PulseLength = 1500.0;
  } 
  else {
    M1ActualSpeed = - Query_Speed(Right_Wheel);
    M1PulseLength += M1PID(M1SpeedSetpoint,M1ActualSpeed, 0.5, 0.0, 0.0);
    M1PulseLength = min(max(M1PulseLength, 1000), 2000);
    M1Control.write((int) M1PulseLength);

    M2ActualSpeed = Query_Speed(Left_Wheel);
    M2PulseLength += M2PID(M2SpeedSetpoint,M2ActualSpeed, 0.5, 0.0, 0.0);
    M2PulseLength = min(max(M2PulseLength, 1000), 2000);
    M2Control.write((int) M2PulseLength);

    js_msg.position_right = - Query_Position(Right_Wheel);
    js_msg.position_left = Query_Position(Left_Wheel);
    js_msg.velocity_right = M1ActualSpeed;
    js_msg.velocity_left = M2ActualSpeed;
    ros.publish(js_pub, &js_msg);
  }
}

double M1PID(double setpoint, double actual, double Kp, double Ki, double Kd)
{


  double error = setpoint - actual;
  double time = millis();
  double dt = (time - M1Prevtime)/1000;
  M1Prevtime = time;
  M1integral = M1integral + (error*dt);
  double derivative = (error - M1previous_error)/dt;
  double output = (Kp*error) + (Ki*M1integral) + (Kd*derivative);
  M1previous_error = error;
  return output;
}

double M2PID(double setpoint, double actual, double Kp, double Ki, double Kd)
{


  double error = setpoint - actual;
  double time = millis();
  double dt = (time - M2Prevtime)/1000;
  M2Prevtime = time;
  M2integral = M2integral + (error*dt);
  double derivative = (error - M2previous_error)/dt;
  double output = (Kp*error) + (Ki*M2integral) + (Kd*derivative);
  M2previous_error = error;
  return output;
}


int Check_For_Arrival(byte Wheel, int Tolerance){
  int Returned_Result; 
  Returned_Result = Tell_Motor( CHFA,  Wheel,  Tolerance);   // Tolerance is zero to 255 ... 0 means exact, 255 is sloppy
  return Returned_Result;
}


int Travel_Number_Of_Positions(byte Wheel, int Distance_To_Travel){
  int Returned_Result; 
  Returned_Result = Tell_Motor( TRVL,  Wheel,  Distance_To_Travel);   // Travel number of encoder steps
  return Returned_Result;
}


int Query_Position(byte Wheel){
  int Returned_Result; 
  Returned_Result = Tell_Motor( QPOS,  Wheel,  0);   // query position
  return Returned_Result;
}


int Query_Speed(byte Wheel){
  int Returned_Result; 
  Returned_Result = Tell_Motor( QSPD,  Wheel,  0);   // query speed
  return Returned_Result;
}



void Set_Orientation_As_Reversed (byte Wheel) {
  int Returned_Result;
  Returned_Result = Tell_Motor( SREV,  Wheel,  0);   //  wheel reversing 
}



void Set_Speed_Maximum (byte Wheel, int Speed) {
  int Returned_Result;
  Returned_Result = Tell_Motor( SMAX,  Wheel,  Speed);   //  set max speed.  Speed is an integer 0 to 65535
}




void Set_Speed_Ramp_Rate (byte Wheel, byte Ramp_Rate) {
  int Returned_Result;
  Returned_Result = Tell_Motor( SSRR,  Wheel,  Ramp_Rate);   //  set max speed.  Speed is an integer 0 to 65535
}



void Set_Transmit_Delay (byte Delay) {
  int Returned_Result;
  // parameter Delay is in units of about 4.34 microseconds.  default is 115 (or about 540 microsecs)
  Returned_Result = Tell_Motor( STXD, 0, Delay);   //  set minimum delay before respoihnd to a query
  // note that no wheel is specified.
}



void Clear_Position (byte Wheel) {
  int Returned_Result;
  Returned_Result = Tell_Motor( CLRP,  Wheel,  0);   // Clear Position of one or both wheels
}





int Tell_Motor(byte Command, byte Address, int In_Parameter) {

# define DEBUG         0x00            // Debug Print.  Set to FF to debug

  int Number_Bytes_To_Write; 
  int Number_Bytes_To_Read;
  int Number_Bytes_In_Input_Queue;
  byte Output_Buffer[4];
  byte Input_Buffer[4];
  int Returned_Result;
  int Returned_Data;


  Output_Buffer[0] = 0;
  Output_Buffer[1] = 0;
  Output_Buffer[2] = 0;
  Output_Buffer[3] = 0;

  Output_Buffer[0] = Command + Address;


  //  flush the input buffer
  Serial3.flush();   //empty the input buffer

  if (Command == QPOS) {       // Query Position. sends 1 byte Command+wheel. Receive integer
    Number_Bytes_To_Write = 1; // 
    Number_Bytes_To_Read = 2;
    if (DEBUG) {
      Serial.print("QPOS "); 
    }
  }
  else if (Command == QSPD) {  // Query Position. sends 1 byte Command+wheel. Receive integer
    Number_Bytes_To_Write = 1; // 
    Number_Bytes_To_Read = 2;  // 
    if (DEBUG) {
      Serial.print("QSPD ");
    } 
  }
  else if (Command == CHFA) {  // Check for Arrival. sends 1 byte Command+wheel, 1 byte Tolerance. Receive 1 byte return (ether 0 or FF)
    Number_Bytes_To_Write = 2; // 
    Number_Bytes_To_Read = 1;  // 
    Output_Buffer[1] = byte(In_Parameter);  // 1 byte parameter - the tolerance
    if (DEBUG) {
      Serial.print("CHFA "); 
    }
  }
  else if (Command == TRVL) { // Travel Number of Positions. sends 1 byte Command+wheel, signed integer distance. Receives nothing
    Number_Bytes_To_Write = 3; // 
    Number_Bytes_To_Read = 0;  //
    Output_Buffer[1] = byte(In_Parameter / 256);  // high byte
    Output_Buffer[2] = byte(In_Parameter);        //least significant of 2 bytes
    if (DEBUG) {
      Serial.print("TRVL ");  
    }  
  }
  else if (Command == CLRP) {   // clear position.  Command and wheel, nothing returned
    Number_Bytes_To_Write = 1; // 
    Number_Bytes_To_Read = 0;  // 
    if (DEBUG) {
      Serial.print("CLRP "); 
    }
  }
  else if (Command == SREV) {  // set orientation as reversed.  Command and wheel, nothing returned
    Number_Bytes_To_Write = 1; // 
    Number_Bytes_To_Read = 0;  //
    if (DEBUG) {
      Serial.print("SREV ");  
    }
  }
  else if (Command == STXD) {   // set transmit delay. Command and wheel and 1 byte delay.  Nothing returned
    Number_Bytes_To_Write = 2; // 
    Number_Bytes_To_Read = 0;  //
    Output_Buffer[1] = byte(In_Parameter);  // the transmit delay in units of about 4.3 microseconds
    if (DEBUG) {
      Serial.print("STXD ");  
    }
  }
  else if (Command == SMAX) {  // set speed maximum.  Command and wheel, then integer speed sent.  Nothing returned
    Number_Bytes_To_Write = 3; // 
    Number_Bytes_To_Read = 0;  //
    Output_Buffer[1] = byte(In_Parameter / 256);  // high byte of the integer speed
    Output_Buffer[2] = byte(In_Parameter);        //least significant byte of integer speed
    if (DEBUG) {
      Serial.print("SMAX "); 
    } 
  }
  else if (Command == SSRR) {  // set speed ramp rate.  command+weel, then 1 byte rate.  Nothing returned
    Number_Bytes_To_Write = 2; // 
    Number_Bytes_To_Read = 0;  //
    Output_Buffer[1] = byte(In_Parameter);  // Acceleration / deceleration for travfel, in units of positions/0.25sec/sec.  power on defaults to 15. 
    if (DEBUG) {
      Serial.print("SSRR "); 
    }
  }

  if (DEBUG) {  
    Serial.print("Tell_Motor Command= ");
    Serial.print(Command, BIN);

    Serial.print(" Address= ");
    Serial.print(Address, BIN);

    Serial.print(" Parameter= ");
    Serial.print(In_Parameter, DEC);


    Serial.print(" Output_Buffer= ");
    for (int i = 0; i < Number_Bytes_To_Write; i++){
      Serial.print(Output_Buffer[i], HEX);
      Serial.print("");
    }

    Serial.print(" Send this many bytes= ");
    Serial.print(Number_Bytes_To_Write, DEC);

    Serial.print(" Rcve this many bytes= ");
    Serial.print(Number_Bytes_To_Read, DEC);

    Serial.println("");
  }

  //  DO THE DEED
  //  SEND THE COMMAND to the PARALLSAX ENCODER/WHEEL MOTOR!!!

  for (int i=0; i<Number_Bytes_To_Write; i++) {
    Serial3.print(Output_Buffer[i],BYTE);
  }


  //   Ok, the command is sent over the serial line.
  delay(DELAY_TIME);  // wait a little for things to settle

  /// GET THE ECHO and possibly a REPLY
  // (at the start of this big function, we flushed the input buffer)  
  // but even if there is no data from the motor to read,
  // we must read it anyways, since there is the echo of our command

  // find the number of bytes that are waiting for us
  Number_Bytes_In_Input_Queue = Serial3.available();  

  if (DEBUG) {
    Serial.print("Number_Bytes_In_Input_Queue=");  
    Serial.print(Number_Bytes_In_Input_Queue, DEC);

    Serial.print(" input bytes are ");
  }

  // Here, we read the bytes echoed by the encoder/motor and also any extra bytes (like a numeric position)
  for(int i = 0; i<Number_Bytes_In_Input_Queue; i++) {
    Input_Buffer[i] = Serial3.read();   // read each byte that is waiting for us
    if (DEBUG) {
      Serial.print(Input_Buffer[i],HEX);  
      Serial.print(".");
    }

  }


  if(Number_Bytes_To_Read == 0) {   // perhaps this is a command which has no data returned, like set speed.
    Returned_Data = 0;              
  }

  else if (Number_Bytes_To_Read == 1) {  // or maybe this command returns one byte of information, like set transmit delay
    // the command caused the encoder/motor to return only 1 byte.
    // so return the topmost byte.
    //  Ignore the first bytes in the Input Buffer, which are the echo of the outgoing command
    Returned_Data = Input_Buffer[Number_Bytes_In_Input_Queue-1];     
  }

  else if (Number_Bytes_To_Read == 2) {   //  or a command that returns 2 bytes, like query position
    // this command causes the encoder/motor to return 2 bytes.
    // so return only the topmost two bytes.
    //  Ignore the first bytes in the Input Buffer, which are the echo of the outgoing command
    //  I am doing an 8 bit shift by multiplying by 256. I'm Lazy...
    Returned_Data = (256*Input_Buffer[Number_Bytes_In_Input_Queue-2]) +Input_Buffer[Number_Bytes_In_Input_Queue-1];     
  }

  if (DEBUG) {     
    Serial.print(" Returned Data=");
    Serial.print(Returned_Data, DEC);

    Serial.println("");
  }
  return Returned_Data;

}

 








