//
//  complex.h
//  Phantom
//
//  Created by TSAR Weasley on 2023/12/3.
//

#ifndef complex_h
#define complex_h

template <typename T>
class Complex {
public:
    T real;
    T image;
public:
    inline static Complex fromAngleLength(T angle, T length) { return Complex(cos(angle), sin(angle)) * length; }
    
    inline Complex (T real = 1, T image = 0) thread : real(real), image(image) { }
    inline Complex (thread const Complex& another) thread : Complex(another.real, another.image) { }
    inline Complex (device const Complex& another) thread : Complex(another.real, another.image) { }
    inline Complex (constant Complex& another) thread : Complex(another.real, another.image) { }
    
    inline bool isReal() const thread { return image == 0; }
    inline bool isImagined() const thread { return real == 0; }
    inline bool isZero() const thread { return image == 0 && real == 0; }
    
    inline T length_squared() const thread { return real * real + image * image; }
    inline T length() const thread { return metal::sqrt(length_squared()); }
    
    inline T angle() const thread { return atan2(image, real); }
    inline Complex sqrt() const thread { return fromAngleLength(angle() / 2, metal::sqrt(length())); }
    
    inline void normalize() thread { *this = normalize(); }
    
    inline Complex normalized() const thread { return *this / length(); }
    inline Complex conjugate() const thread { return Complex(real, -image); }
    
    inline Complex operator + (thread const Complex& another) const thread { return Complex(this->real + another.real, this->image + another.image); }
    inline Complex operator + (thread const T& scalar) const thread { return Complex(real + scalar, image); }
    
    inline Complex operator - () const thread { return Complex(-this->real, -this->image); }
    inline Complex operator - (thread const Complex& another) const thread { return *this + (-another); }
    inline Complex operator - (thread const T& scalar) const thread { return *this + (-scalar); }
    
    inline Complex operator * (thread const Complex& another) const thread {
        T r = this->real * another.real - this->image * another.image;
        T i = this->image * another.real + this->real * another.image;
        return Complex(r, i);
    }
    
    inline Complex<T> operator * (thread const T& scalar) const thread { return Complex<T>(scalar * this->real, scalar * this->image); }
    
    inline Complex operator / (thread const T& scalar) const thread { return Complex(this->real / scalar, this->image / scalar); }
    inline Complex operator / (thread const Complex& another) const thread {
        Complex numerator = *this * another.conjugate();
        T denominator = (another * another.conjugate()).real;
        return numerator / denominator;
    }
    
    inline thread Complex& operator += (thread const T& scalar) thread { this->real += scalar; return *this; }
    inline thread Complex& operator -= (thread const T& scalar) thread { this->real -= scalar; return *this;}
    inline thread Complex& operator += (thread const Complex& scalar) thread { return *this = *this + scalar; }
    inline thread Complex& operator -= (thread const Complex& scalar) thread { return *this = *this - scalar; }
    
    inline thread Complex& operator *= (thread const T& scalar) thread { this->real *= scalar; return *this; }
    inline thread Complex& operator /= (thread const T& scalar) thread { this->real /= scalar; return *this;}
    inline thread Complex& operator *= (thread const Complex& scalar) thread { return *this = *this * scalar; }
    inline thread Complex& operator /= (thread const Complex& scalar) thread { return *this = *this / scalar; }
    
//    friend Complex<T> operator + (thread const T& a, thread const Complex<T>& b);
//    friend Complex<T> operator - (thread const T& a, thread const Complex<T>& b);
//    friend Complex<T> operator * (thread const T& a, thread const Complex<T>& b);
//    friend Complex<T> operator / (thread const T& a, thread const Complex<T>& b);
};

//template <typename T>
//Complex<T> operator - (thread const T& a, thread const Complex<T>& b) { return Complex<T>(b.real - a, b.image); }
//
//template <typename T>
//Complex<T> operator + (thread const T& a, thread const Complex<T>& b) { return Complex<T>(b.real + a, b.image); }
//
//template <typename T>
//Complex<T> operator * (thread const T& a, thread const Complex<T>& b) { return Complex<T>(b.real * a, b.image * a); }
//
//template <typename T>
//Complex<T> operator / (thread const T& a, thread const Complex<T>& b) {
//    Complex<T> numerator = a * b.conjugate();
//    float denominator = (b * b.conjugate()).real;
//    return numerator / denominator;
//}

template<typename T, uint dimension>
class ComplexVector {
public:
    Complex<T> vec[dimension];
public:
    inline ComplexVector(thread const Complex<T>& value) thread {
        for (int i = 0; i < dimension; i++) vec[i] = value;
    }
    
    inline ComplexVector(thread const ComplexVector & another) thread {
        for (int i = 0; i < dimension; i++) vec[i] = another.vec[i];
    }
    
    inline ComplexVector angle() const thread {
        ComplexVector result(0);
        for (int i = 0; i < dimension; i++) result.vec[i] = vec[i].angle();
        return result;
    }
    
    inline ComplexVector sqrt() const thread {
        ComplexVector result(0);
        for (int i = 0; i < dimension; i++) result.vec[i] = vec[i].sqrt();
        return result;
    }
    
    inline void normalize() thread {
        for (int i = 0; i < dimension; i++) vec[i].normalize();
    }
    
    inline ComplexVector normalized() const thread {
        ComplexVector result(0);
        for (int i = 0; i < dimension; i++) result.vec[i] = vec[i].normalized();
        return result;
    }
    inline ComplexVector conjugate() const thread {
        ComplexVector result(0);
        for (int i = 0; i < dimension; i++) result.vec[i] = vec[i].conjugate();
        return result;
    }
    
    inline ComplexVector operator + (thread const ComplexVector& another) const thread {
        ComplexVector result(another);
        for (int i = 0; i < dimension; i++) result.vec[i] += vec[i];
        return result;
    }
    
    inline ComplexVector operator + (thread const Complex<T>& scalar) const thread {
        ComplexVector result(*this);
        for (int i = 0; i < dimension; i++) result.vec[i] += scalar;
        return result;
    }
    
    inline ComplexVector operator + (thread const T& scalar) const thread {
        ComplexVector result(*this);
        for (int i = 0; i < dimension; i++) result.vec[i] += scalar;
        return result;
    }
    
    inline ComplexVector operator - () const thread {
        ComplexVector result(*this);
        for (int i = 0; i < dimension; i++) result.vec[i] *= -1;
        return result;
    }
    
    inline ComplexVector operator - (thread const ComplexVector& another) const thread { return *this + (-another); }
    inline ComplexVector operator - (thread const Complex<T>& scalar) const thread { return *this + (-scalar); }
    inline ComplexVector operator - (thread const T& scalar) const thread { return *this + (-scalar); }
    
    
    inline ComplexVector operator * (thread const ComplexVector& another) const thread {
        ComplexVector result(another);
        for (int i = 0; i < dimension; i++) result.vec[i] *= vec[i];
        return result;
    }
    
    inline ComplexVector operator * (thread const Complex<T>& scalar) const thread {
        ComplexVector result(*this);
        for (int i = 0; i < dimension; i++) result.vec[i] *= scalar;
        return result;
    }
    
    inline ComplexVector operator * (thread const T& scalar) const thread {
        ComplexVector result(*this);
        for (int i = 0; i < dimension; i++) result.vec[i] *= scalar;
        return result;
    }
    
    inline ComplexVector operator / (thread const ComplexVector& another) const thread {
        ComplexVector result(*this);
        for (int i = 0; i < dimension; i++) result.vec[i] /= another.vec[i];
        return result;
    }
    
    inline ComplexVector operator / (thread const Complex<T>& scalar) const thread {
        ComplexVector result(*this);
        for (int i = 0; i < dimension; i++) result.vec[i] /= scalar;
        return result;
    }
    
    inline ComplexVector operator / (thread const T& scalar) const thread {
        ComplexVector result(*this);
        for (int i = 0; i < dimension; i++) result.vec[i] /= scalar;
        return result;
    }
    
    inline Complex<T> dot(thread const ComplexVector& another) const thread {
        Complex<T> result = Complex<T>(0, 0);
        for (int i = 0; i < dimension; i++) result += vec[i] * another.vec[i];
        return result;
    }
    
    thread Complex<T>& operator[] (int index) thread { return vec[index]; }
    const thread Complex<T>& operator[] (int index) const thread { return vec[index]; }
};

using floatc = Complex<float>;
using halfc = Complex<half>;
using floatc3 = ComplexVector<float, 3>;
using halfc3 = ComplexVector<half, 3>;

//simd

//class floatc {
//private:
//    float real;
//    float image;
//public:
//    inline floatc (float real = 1, float image = 0): real(real), image(image) { }
//    
//    inline bool isReal() const { return image == 0; }
//    inline bool isImagined() const { return real == 0; }
//    inline bool isZero() const { return image == 0 && real == 0; }
//    
//    inline float length_squared() const { return real * real + image * image; }
//    inline float length() const { return sqrt(length_squared()); }
//    
//    inline float angle() const { return atan2(image, real); }
//    
//    inline floatc normalized() const { return *this / length(); }
//    inline floatc conjugate() const { return floatc(real, -image); }
//    
//    inline floatc operator + (floatc another) const { return floatc(this->real + another.real, this->image + another.image); }
//    inline floatc operator + (float scalar) const { return floatc(this->real + scalar, this->image); }
//    friend floatc operator + (float a, floatc b);
//    
//    inline floatc operator - () const { return floatc(-this->real, -this->image); }
//    inline floatc operator - (floatc another) const { return *this + (-another); }
//    inline floatc operator - (float scalar) const { return *this + (-scalar); }
//    friend floatc operator - (float a, floatc b);
//    
//    inline floatc operator * (floatc another) const {
//        float r = this->real * another.real - this->image * another.image;
//        float i = this->image * another.real + this->real * another.image;
//        return floatc(r, i);
//    }
//    
//    inline floatc operator * (float scalar) const { return floatc(scalar * this->real, scalar * this->image); }
//    friend floatc operator * (float a, floatc b);
//    
//    inline floatc operator / (float scalar) const { return floatc(this->real / scalar, this->image / scalar); }
//    inline floatc operator / (floatc another) const {
//        floatc numerator = *this * another.conjugate();
//        float denominator = (another * another.conjugate()).real;
//        return numerator / denominator;
//    }
//    friend floatc operator / (float a, floatc b);
//};

#endif /* complex_h */
