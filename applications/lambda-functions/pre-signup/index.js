            'outlook.com',
            'hotmail.com',
            'edu',  // Educational institutions
            'org',  // Organizations
            'university.edu',  // Example university domain
            'school.edu'       // Example school domain
        ];

        // Check email domain
        const emailDomain = email.split('@')[1];
        const isDomainAllowed = allowedEmailDomains.some(domain => 
            emailDomain === domain || emailDomain.endsWith('.' + domain)
        );

        if (!isDomainAllowed) {
            validations.push(`Email domain ${emailDomain} is not allowed`);
        }

        // 2. Role-specific validations
        if (customRole === 'student') {
            // Students should have a student ID
            if (!customStudentId || customStudentId.length < 5) {
                validations.push('Students must provide a valid student ID (minimum 5 characters)');
            }

            // Student ID format validation (example: starts with 'S' followed by numbers)
            if (customStudentId && !/^S\d{6,}$/.test(customStudentId)) {
                validations.push('Student ID must start with "S" followed by at least 6 digits');
            }

            // Students should have a department
            if (!customDepartment) {
                validations.push('Students must specify their department');
            }
        }

        if (customRole === 'teacher') {
            // Teachers should have a department
            if (!customDepartment) {
                validations.push('Teachers must specify their department');
            }

            // Teacher email should be from educational domain for verification
            if (!emailDomain.includes('edu') && !emailDomain.includes('school')) {
                console.log(`Warning: Teacher ${email} is not using an educational email domain`);
                // Note: This is logged as warning but doesn't block signup
            }
        }

        if (customRole === 'admin') {
            // Admin accounts require special approval (this could be enhanced)
            console.log(`Admin signup attempt by ${email} - requires manual review`);
            
            // For now, allow admin signup but log for review
            // In production, you might want to require pre-approval
        }

        // 3. Department validation
        const allowedDepartments = [
            'Computer Science',
            'Mathematics',
            'Physics',
            'Chemistry',
            'Biology',
            'Engineering',
            'Business',
            'Arts',
            'Literature',
            'History',
            'Psychology',
            'Economics',
            'Administration'
        ];

        if (customDepartment && !allowedDepartments.includes(customDepartment)) {
            validations.push(`Department "${customDepartment}" is not recognized. Please choose from the approved list.`);
        }

        // 4. Additional custom validations
        // Check for duplicate student IDs (this would require a database lookup in real implementation)
        if (customRole === 'student' && customStudentId) {
            // In a real implementation, you would check against a database
            // For demo purposes, we'll just validate format
            console.log(`Validating student ID uniqueness: ${customStudentId}`);
        }

        // If there are validation errors, throw an exception
        if (validations.length > 0) {
            const errorMessage = validations.join('; ');
            console.log(`Pre-signup validation failed: ${errorMessage}`);
            
            throw new Error(errorMessage);
        }

        // Auto-confirm user for certain domains (optional)
        if (emailDomain.endsWith('.edu') || emailDomain.endsWith('.school.edu')) {
            event.response.autoConfirmUser = true;
            event.response.autoVerifyEmail = true;
            console.log(`Auto-confirming user from educational domain: ${email}`);
        }

        // Set user attributes that should be verified
        event.response.autoVerifyEmail = false;  // Require email verification
        event.response.autoVerifyPhone = false; // We're not using phone verification

        console.log(`Pre-signup validation successful for: ${email}`);
        return event;

    } catch (error) {
        console.error('Pre-signup validation error:', error);
        
        // Return the error to prevent signup
        throw new Error(`Registration validation failed: ${error.message}`);
    }
};

/**
 * Helper function to validate email format
 */
function isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
}

/**
 * Helper function to validate student ID format
 */
function isValidStudentId(studentId, role) {
    if (role !== 'student') return true; // Not required for non-students

    // Example validation: Student ID should be S followed by 6+ digits
    const studentIdRegex = /^S\d{6,}$/;
    return studentIdRegex.test(studentId);
}

/**
 * Helper function to check if department is valid
 */
function isValidDepartment(department) {
    const allowedDepartments = [
        'Computer Science',
        'Mathematics',
        'Physics',
        'Chemistry',
        'Biology',
        'Engineering',
        'Business',
        'Arts',
        'Literature',
        'History',
        'Psychology',
        'Economics',
        'Administration'
    ];
    
    return allowedDepartments.includes(department);
}
