#!/bin/bash

log_message_file="/var/log/user_management.log"
passwords_file="/var/secure/user_passwords.txt"

# Check if a user exists
user_exists() {
    local username=$1
    if getent passwd "$username" > /dev/null 2>&1; then
        return 0  # User exists
    else
        return 1  # User does not exist
    fi
}

# Check if a group exists
group_exists() {
    local group_name=$1
    if getent group "$group_name" > /dev/null 2>&1; then
        return 0  # Group exists
    else
        return 1  # Group does not exist
    fi
}

# Generate a random password
generate_password() {
    openssl rand -base64 12
}

# Log actions to /var/log/user_management.log
log() {
    local MESSAGE="$1"
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $MESSAGE" | sudo tee -a $log_message_file > /dev/null
}


# Assign the file name from the command line argument
user_group=$1

# Check if the log file exist

if [ ! -f "$log_messsage_file" ]; then
    # Create the log file
    sudo touch "$log_message_file"
    log "$log_message_file has been created."
else
    log "$log_message_file exists already"
fi

# Check and create the passwords_file

if [ ! -f "$passwords_file" ]; then
    # Create the file and set permissions
    sudo mkdir -p /var/secure/
    sudo touch "$passwords_file"
    log "$passwords_file has been created."
    # Set ownership permissions for passwords_file
    sudo chmod 600 "$passwords_file"
    log "Updated passwords_file permission to file owner"
else
    log "$passwords_file exists already"
fi

echo "#######################################"
echo "Generating Users and Groups"

# Read the file line by line and process
while IFS=';' read -r username groups; do
    # Extract the user name
    username=$(echo "$username" | xargs)

    # Check if the user exists
    if user_exists "$username"; then
        log "$username exists already"
        continue
    else
        # Generate a random password for the user
        password=$(generate_password)

        # Create the user with home directory and set password
        sudo useradd -m -s /bin/bash "$username"
        echo "$username:$password" | sudo chpasswd

        log "Successfully Created User: $username"
    fi

    # check that the user has its own group
    if ! group_exists "$username"; then
        sudo groupadd "$username"
        log "Successfully created group: $username"
        sudo usermod -aG "$username" "$username"
        log "User: $username added to Group: $username"
    else
        log "User: $username added to Group: $username"
    fi

    # Extract the groups and remove any spaces
    groups=$(echo "$groups" | tr -d ' ')

    # Split the groups by comma
    IFS=',' read -r -a group_count <<< "$groups"

    # Create the groups and add the user to each group
    for group in "${group_count[@]}"; do
        # Check if the group already exists
        if ! group_exists "$group"; then
            # Create the group if it does not exist
            sudo groupadd "$group"
            log "Successfully created Group: $group"
        else
            log "Group: $group already exists"
        fi
        # Add the user to the group
        sudo usermod -aG "$group" "$username"
    done

    # Set permissions for home directory
    sudo chmod 700 "/home/$username"
    sudo chown "$username:$username" "/home/$username"
    log "Updated permissions for home directory: '/home/$username' of User: $username to '$username:$username'"

    # Log the user created action
    log "Successfully Created user: $username with Groups: $username ${group_count[*]}"

    # Store username and password in secure file
    echo "$username,$password" | sudo tee -a "$passwords_file" > /dev/null
    log "Stored username and password in $passwords_file"
done < "$user_group"

# Log the script execution to standard output
echo "#######################################"
echo "Script Succesfully Executed"